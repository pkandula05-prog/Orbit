import CoreLocation
import Foundation

/// Where the dots on the ring come from.
///
/// **Apple's Find My has no public API.** It is a closed system — there is no supported way
/// for a third-party app to read the locations of your Find My friends, and anything that
/// claims to breaks the moment Apple changes it and puts the account at risk. Orbit does not
/// do that. It reads a feed you control, behind this one interface.
protocol FriendSource: Sendable {
    var id: String { get }
    var label: String { get }
    /// Emits the whole roster each time any of it changes.
    func stream() -> AsyncStream<[FriendLocation]>
}

/// The roster from the artboards, drifting slowly so the dial behaves like a live feed.
///
/// It scatters that roster around *your* position once a real fix arrives, so the compass is
/// useful wherever it is run. This is the default, so the app needs no backend to be usable.
struct MockFriendSource: FriendSource {
    struct Seed: Sendable {
        let id: String, name: String, initial: String
        let bearing: Double, metres: Double, driftMps: Double
    }

    /// Bearings and distances are the ones drawn on artboards 5a / 5b.
    static let seeds: [Seed] = [
        Seed(id: "ana", name: "Ana", initial: "A", bearing: 47, metres: 1200, driftMps: 1.4),
        Seed(id: "miles", name: "Miles", initial: "M", bearing: 112, metres: 3800, driftMps: 0.6),
        Seed(id: "jae", name: "Jae", initial: "J", bearing: 205, metres: 5100, driftMps: 2.1),
        Seed(id: "priya", name: "Priya", initial: "P", bearing: 298, metres: 640, driftMps: 0.9),
        Seed(id: "noor", name: "Noor", initial: "N", bearing: 18, metres: 2400, driftMps: 0.4),
        Seed(id: "tobi", name: "Tobi", initial: "T", bearing: 154, metres: 900, driftMps: 1.1),
        Seed(id: "wren", name: "Wren", initial: "W", bearing: 241, metres: 7300, driftMps: 0.3),
        Seed(id: "kai", name: "Kai", initial: "K", bearing: 331, metres: 1850, driftMps: 1.7),
    ]

    static let demoOrigin = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

    let id = "mock"
    let label = "Demo roster"
    /// Read at each tick rather than captured once, so the roster re-anchors around the
    /// device as soon as a real fix arrives — otherwise everyone sits in San Francisco.
    let origin: @Sendable () -> CLLocationCoordinate2D
    var interval: Duration = .seconds(4)
    /// Which seeds are visible: onboarding only ever hands over the people who accepted.
    var visible: [String] = seeds.map(\.id)

    func stream() -> AsyncStream<[FriendLocation]> {
        AsyncStream { continuation in
            let task = Task {
                let startedAt = ContinuousClock.now
                while !Task.isCancelled {
                    let elapsed = (ContinuousClock.now - startedAt).seconds
                    continuation.yield(snapshot(after: elapsed))
                    try? await Task.sleep(for: interval)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func snapshot(after seconds: Double) -> [FriendLocation] {
        let here = origin()
        return Self.seeds.enumerated().compactMap { index, seed in
            guard visible.contains(seed.id) else { return nil }
            let wander = sin(seconds / 30 + Double(index)) * seed.driftMps * 40
            let point = Geo.destination(
                from: here,
                bearing: seed.bearing + sin(seconds / 45 + Double(index)) * 3,
                metres: max(60, seed.metres + wander)
            )
            return FriendLocation(id: seed.id, name: seed.name, initial: seed.initial,
                                  latitude: point.latitude, longitude: point.longitude,
                                  updatedAt: Date())
        }
    }
}

/// Polls a JSON endpoint you host:
///
/// ```json
/// { "friends": [ { "id": "ana", "name": "Ana", "latitude": 37.78, "longitude": -122.40,
///                  "updatedAt": 1757030400000 } ] }
/// ```
///
/// If you want Find My-*like* behaviour, the shape that actually works is friends running
/// Orbit and opting into sharing, posting their own fixes to a backend you host, which then
/// serves this. Everything on the client is already written against that.
struct RESTFriendSource: FriendSource {
    struct Payload: Decodable {
        struct Entry: Decodable {
            let id: String
            let name: String
            let initial: String?
            let latitude: Double
            let longitude: Double
            /// Milliseconds since the epoch, as a JSON feed usually writes a timestamp.
            let updatedAt: Double?
        }
        let friends: [Entry]
    }

    let id = "rest"
    let label = "Shared feed"
    let endpoint: URL
    var token: String?
    var interval: Duration = .seconds(10)

    func stream() -> AsyncStream<[FriendLocation]> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    if let friends = try? await fetch() { continuation.yield(friends) }
                    try? await Task.sleep(for: interval)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func fetch() async throws -> [FriendLocation] {
        var request = URLRequest(url: endpoint)
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Payload.self, from: data).friends.map { entry in
            FriendLocation(
                id: entry.id,
                name: entry.name,
                initial: entry.initial ?? String(entry.name.prefix(1)).uppercased(),
                latitude: entry.latitude,
                longitude: entry.longitude,
                updatedAt: entry.updatedAt.map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date()
            )
        }
    }
}

private extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
