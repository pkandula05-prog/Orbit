import CoreLocation
import Foundation
import Supabase

/// Friends' positions, straight off Postgres.
///
/// The initial read and the realtime stream both go through the same row level security policy,
/// so this asks for every location row and receives only the ones where sharing is mutual and
/// accepted. There is no filtering in Swift to get wrong.
struct SupabaseFriendSource: FriendSource {
    let id = "supabase"
    let label = "Shared with you"
    let client: SupabaseClient
    /// Names live on `profiles`; positions on `locations`. Held by the app, which already
    /// knows the roster, rather than joined on every tick.
    let names: @Sendable (String) -> (name: String, initial: String)?

    func stream() -> AsyncStream<[FriendLocation]> {
        AsyncStream { continuation in
            let task = Task {
                var latest: [String: FriendLocation] = [:]

                func publish(_ rows: [LocationRow]) {
                    for row in rows {
                        guard let who = names(row.user_id) else { continue }
                        latest[row.user_id] = FriendLocation(
                            id: row.user_id, name: who.name, initial: who.initial,
                            latitude: row.latitude, longitude: row.longitude,
                            updatedAt: row.updated_at
                        )
                    }
                    continuation.yield(Array(latest.values))
                }

                if let rows: [LocationRow] = try? await client.from("locations").select().execute().value {
                    publish(rows)
                }

                let channel = client.channel("orbit-locations")
                let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "locations")
                await channel.subscribe()

                for await change in changes {
                    guard !Task.isCancelled else { break }
                    if let row = try? change.decodeRecord(as: LocationRow.self, decoder: JSONDecoder()) {
                        publish([row])
                    }
                }

                await channel.unsubscribe()
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Pushes your own position up, so the people you share with can see it.
///
/// Nothing is written until there is somebody to write it for: with no accepted invite the
/// publisher stays quiet, so a user who has never shared has no position stored at all.
@MainActor
final class LocationPublisher {
    private let client: SupabaseClient?
    private var lastWrite = Date.distantPast
    /// Ten seconds is frequent enough for a dial and slow enough to be kind to the battery.
    private let interval: TimeInterval = 10

    init(client: SupabaseClient? = SupabaseService.shared) {
        self.client = client
    }

    func publish(_ coordinate: CLLocationCoordinate2D, course: Double?, speed: Double?, hasFriends: Bool) {
        guard let client, hasFriends,
              Date().timeIntervalSince(lastWrite) >= interval,
              let id = client.auth.currentUser?.id.uuidString.lowercased()
        else { return }
        lastWrite = Date()

        let row = LocationRow(user_id: id,
                              latitude: coordinate.latitude,
                              longitude: coordinate.longitude,
                              course: course,
                              speed: speed,
                              updated_at: Date())
        Task { try? await client.from("locations").upsert(row).execute() }
    }
}
