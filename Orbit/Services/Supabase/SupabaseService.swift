import Foundation
import Supabase

/// The one place the project is configured. `SupabaseURL` and `SupabaseAnonKey` come from the
/// app's Info.plist, which reads them from build settings, so no key is in source.
///
/// The anon key is meant to ship in a client. It grants nothing on its own: every table is
/// behind row level security, so what a request may see is decided by the signed-in user. The
/// service role key must never appear in this app.
enum SupabaseService {
    static let shared: SupabaseClient? = {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              !raw.isEmpty, let url = URL(string: raw),
              let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
              !key.isEmpty
        else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()

    static var isConfigured: Bool { shared != nil }
}

// MARK: - Rows

struct OrbitRow: Codable, Sendable {
    var id: String
    var host_user: String
    var expires_at: Date
    var ended_at: Date?

    var session: OrbitSession {
        OrbitSession(id: id, hostUserID: host_user, expiresAt: expires_at, endedAt: ended_at)
    }
}

struct CreatedOrbitRow: Codable, Sendable {
    var orbit_id: String
    var token: String
    var orbit_expires_at: Date
    var token_expires_at: Date
}

struct TokenRow: Codable, Sendable {
    var token: String
    var expires_at: Date
}

struct ParticipantRow: Codable, Sendable {
    var id: String
    var orbit_id: String
    var user_id: String
    var display_name: String
    var joined_at: Date
    var left_at: Date?

    func participant(me: String, host: String) -> Participant {
        Participant(id: id, displayName: display_name, joinedAt: joined_at, leftAt: left_at,
                    isSelf: user_id == me, isHost: user_id == host)
    }
}

struct PositionRow: Codable, Sendable {
    var participant_id: String
    var latitude: Double
    var longitude: Double
    var accuracy: Double?
    var updated_at: Date

    var fix: ParticipantFix {
        ParticipantFix(participantID: participant_id, latitude: latitude, longitude: longitude,
                       accuracy: accuracy, updatedAt: updated_at)
    }
}
