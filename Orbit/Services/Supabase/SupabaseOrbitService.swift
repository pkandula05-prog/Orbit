import CoreLocation
import Foundation
import Supabase

/// `OrbitService` against Supabase.
///
/// Every rule that matters — who may read a position, when a link stops working, how full an
/// orbit is, when it expires — lives in `Supabase/schema.sql` as a policy or a function. This
/// type only asks; the database decides and can say no.
struct SupabaseOrbitService: OrbitService {
    let client: SupabaseClient

    private var userID: String? { client.auth.currentUser?.id.uuidString.lowercased() }

    /// Anonymous by default. Nobody is asked for a phone number to point at a friend.
    @discardableResult
    func ensureIdentity() async throws -> String {
        if let existing = userID { return existing }
        let session = try await client.auth.signInAnonymously()
        return session.user.id.uuidString.lowercased()
    }

    func create(hours: Int, displayName: String) async throws -> OrbitSession {
        try await ensureIdentity()
        let rows: [CreatedOrbitRow] = try await client
            .rpc("create_orbit", params: ["hours": AnyJSON.integer(hours),
                                          "display_name": .string(displayName)])
            .execute().value
        guard let row = rows.first, let me = userID else { throw OrbitError.orbitOver }

        return OrbitSession(id: row.orbit_id, hostUserID: me, expiresAt: row.orbit_expires_at,
                            joinToken: row.token, tokenExpiresAt: row.token_expires_at)
    }

    func join(token: String, displayName: String) async throws -> OrbitSession {
        try await ensureIdentity()
        do {
            let id: String = try await client
                .rpc("join_orbit", params: ["join_token": token, "display_name": displayName])
                .execute().value
            return try await fetch(id)
        } catch {
            throw OrbitError(postgres: "\(error)") ?? error
        }
    }

    private func fetch(_ id: String) async throws -> OrbitSession {
        let rows: [OrbitRow] = try await client.from("orbits").select().eq("id", value: id)
            .limit(1).execute().value
        guard let row = rows.first else { throw OrbitError.orbitOver }
        return row.session
    }

    func extend(_ orbit: OrbitSession, hours: Int) async throws -> OrbitSession {
        do {
            let expiry: Date = try await client
                .rpc("extend_orbit", params: ["orbit": AnyJSON.string(orbit.id),
                                              "hours": .integer(hours)])
                .execute().value
            var updated = orbit
            updated.expiresAt = expiry
            return updated
        } catch {
            throw OrbitError(postgres: "\(error)") ?? error
        }
    }

    func regenerateLink(_ orbit: OrbitSession) async throws -> OrbitSession {
        let rows: [TokenRow] = try await client
            .rpc("regenerate_token", params: ["orbit": orbit.id]).execute().value
        guard let row = rows.first else { throw OrbitError.notHost }
        var updated = orbit
        updated.joinToken = row.token
        updated.tokenExpiresAt = row.expires_at
        return updated
    }

    func leave(_ orbit: OrbitSession) async throws {
        try await client.rpc("leave_orbit", params: ["orbit": orbit.id]).execute()
    }

    func end(_ orbit: OrbitSession) async throws {
        try await client.rpc("end_orbit", params: ["orbit": orbit.id]).execute()
    }

    /// Reads the roster and every position once, then follows both over Realtime. The same
    /// policies apply to the subscription as to the read, so this asks for everything and is
    /// given only what this participant is allowed to see.
    func updates(for orbit: OrbitSession) -> AsyncStream<OrbitUpdate> {
        AsyncStream { continuation in
            let task = Task {
                await refresh(orbit, into: continuation)

                let channel = client.channel("orbit-\(orbit.id)")
                let changes = channel.postgresChange(AnyAction.self, schema: "public")
                await channel.subscribe()

                for await _ in changes {
                    guard !Task.isCancelled else { break }
                    // The roster is at most six people and a change is rare, so re-reading is
                    // simpler and less wrong than patching rows in from the payload.
                    await refresh(orbit, into: continuation)
                }
                await channel.unsubscribe()
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func refresh(_ orbit: OrbitSession,
                         into continuation: AsyncStream<OrbitUpdate>.Continuation) async {
        guard let me = userID else { return }

        if let session = try? await fetch(orbit.id) {
            continuation.yield(.session(session))
        }
        if let rows: [ParticipantRow] = try? await client.from("participants")
            .select().eq("orbit_id", value: orbit.id).execute().value {
            continuation.yield(.participants(rows.map { $0.participant(me: me, host: orbit.hostUserID) }))
        }
        if let rows: [PositionRow] = try? await client.from("positions").select().execute().value {
            continuation.yield(.fixes(rows.map(\.fix)))
        }
    }

    /// Writes go to your own participant row. The policy checks the orbit is still live, so a
    /// client that keeps publishing after an orbit ends is simply refused.
    func publish(_ fix: CLLocationCoordinate2D, accuracy: Double?, in orbit: OrbitSession) async throws {
        guard let me = userID else { return }
        let rows: [ParticipantRow] = try await client.from("participants")
            .select().eq("orbit_id", value: orbit.id).eq("user_id", value: me).limit(1)
            .execute().value
        guard let mine = rows.first else { return }

        let row = PositionRow(participant_id: mine.id, latitude: fix.latitude,
                              longitude: fix.longitude, accuracy: accuracy, updated_at: Date())
        try await client.from("positions").upsert(row).execute()
    }
}
