import Foundation
import Supabase

/// `AccountBackend` against Supabase: phone one-time codes for sign-in, and the invite graph
/// in Postgres. Every guarantee the app relies on is a row level security policy in
/// `Supabase/schema.sql` — this type only ever asks; the database decides.
struct SupabaseAccountBackend: AccountBackend {
    let client: SupabaseClient

    private var currentUserID: String? {
        client.auth.currentUser?.id.uuidString.lowercased()
    }

    // MARK: - Sign in

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        try await client.rpc("username_available", params: ["name": username.lowercased()])
            .execute()
            .value
    }

    /// Supabase sends the SMS itself through whichever provider the project is configured
    /// with, so there is no code for the client to hold on to.
    func sendCode(to phone: String) async throws -> String {
        try await client.auth.signInWithOTP(phone: normalise(phone))
        return ""
    }

    /// Verifying signs the session in; the profile row is written straight after, which is why
    /// a username that was free at check time is re-checked by the unique index here.
    func verify(code: String, sentCode: String, profile: Profile) async throws {
        try await client.auth.verifyOTP(phone: normalise(profile.phone), token: code, type: .sms)

        guard let id = currentUserID else { throw AccountError.badCode }
        let row = ProfileRow(id: id,
                             first_name: profile.firstName,
                             last_name: profile.lastName,
                             username: profile.username.lowercased(),
                             phone: normalise(profile.phone))
        do {
            try await client.from("profiles").upsert(row).execute()
        } catch {
            // The unique index is the authority, and this is the race the availability check
            // cannot close: someone took the name between checking and signing up.
            throw AccountError.usernameTaken
        }
    }

    // MARK: - People

    func match(phones: [String]) async throws -> [Contact] {
        let normalised = Array(Set(phones.map(normalise))).filter { $0.count > 7 }
        guard !normalised.isEmpty else { return [] }

        let rows: [ProfileRow] = try await client
            .rpc("match_contacts", params: ["phones": normalised])
            .execute()
            .value
        return rows.map { $0.contact }
    }

    func search(_ term: String) async throws -> [Contact] {
        guard term.count >= 2 else { return [] }
        let rows: [ProfileRow] = try await client
            .rpc("search_people", params: ["term": term])
            .execute()
            .value
        return rows.map { var c = $0.contact; c.source = .search; return c }
    }

    /// Both directions at once: the graph is small, and one round trip keeps the page honest.
    func invites() async throws -> [Contact] {
        guard let me = currentUserID else { return [] }

        let rows: [InviteRow] = try await client.from("invites")
            .select()
            .execute()
            .value
        guard !rows.isEmpty else { return [] }

        let others = rows.map { $0.from_user == me ? $0.to_user : $0.from_user }
        let profiles: [ProfileRow] = try await client.from("profiles")
            .select()
            .in("id", values: others)
            .execute()
            .value

        return rows.compactMap { invite in
            let otherID = invite.from_user == me ? invite.to_user : invite.from_user
            guard let profile = profiles.first(where: { $0.id == otherID }) else { return nil }

            var contact = profile.contact
            contact.source = .invite
            switch (invite.status, invite.from_user == me) {
            case ("accepted", _): contact.relation = .sharing
            case ("pending", true): contact.relation = .invitedByMe
            case ("pending", false): contact.relation = .invitedMe
            default: contact.relation = .none
            }
            // The invite's own id is what `respond` needs, not the person's.
            contact.inviteID = invite.id
            return contact
        }
    }

    func invite(_ ids: [String]) async throws {
        guard let me = currentUserID else { return }
        let rows = ids.map { ["from_user": me, "to_user": $0, "status": "pending"] }
        try await client.from("invites").upsert(rows, onConflict: "from_user,to_user").execute()
    }

    /// Someone with no account yet. The row is only a record that it was sent; they arrive
    /// through the link and the invite is made when they sign up.
    func inviteByPhone(_ phone: String) async throws {
        guard phone.filter(\.isNumber).count >= 7 else { throw AccountError.badPhone }
        try await client.functions.invoke("invite-sms", options: .init(body: ["phone": normalise(phone)]))
    }

    func respond(to id: String, accept: Bool) async throws {
        try await client.rpc("respond_to_invite", params: ["invite": id, "accept": String(accept)])
            .execute()
    }

    /// Postgres changes on `invites`, filtered by the same policies as everything else, so a
    /// request or an acceptance arrives without polling.
    func events() -> AsyncStream<AccountEvent> {
        AsyncStream { continuation in
            let task = Task {
                let channel = client.channel("orbit-invites")
                let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "invites")
                await channel.subscribe()

                for await _ in changes {
                    guard !Task.isCancelled else { break }
                    // The row alone does not carry the other person's name, and the graph is
                    // small, so the simplest correct move is to re-read it.
                    guard let refreshed = try? await invites() else { continue }
                    for contact in refreshed {
                        switch contact.relation {
                        case .invitedMe: continuation.yield(.invited(contact))
                        case .sharing: continuation.yield(.accepted(contact))
                        default: break
                        }
                    }
                }
                await channel.unsubscribe()
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Digits only, with a country code. A real app should use libPhoneNumber and the device
    /// region; this is deliberately simple and assumes +1 when none is given.
    private func normalise(_ phone: String) -> String {
        let digits = phone.filter(\.isNumber)
        if phone.hasPrefix("+") { return "+" + digits }
        return digits.count == 10 ? "+1" + digits : "+" + digits
    }
}
