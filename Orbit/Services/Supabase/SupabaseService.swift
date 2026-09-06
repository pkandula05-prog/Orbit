import Foundation
import Supabase

/// The one place the project is configured. `SupabaseURL` and `SupabaseAnonKey` come from the
/// app's Info.plist, which reads them from build settings — so the keys are not in the source.
///
/// The anon key is *meant* to ship in the client. It grants nothing on its own: every table is
/// behind row level security, so what a request can see is decided by the signed-in user, not
/// by the key. The service role key must never appear in this app.
enum SupabaseService {
    static let shared: SupabaseClient? = {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: raw), !raw.isEmpty,
              let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
              !key.isEmpty
        else { return nil }

        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()

    /// False until the keys are filled in, which is what keeps the app running on the local
    /// stand-in with no configuration at all.
    static var isConfigured: Bool { shared != nil }
}

// MARK: - Rows

/// `public.profiles`.
struct ProfileRow: Codable, Sendable {
    var id: String
    var first_name: String
    var last_name: String
    var username: String
    var phone: String?

    var contact: Contact {
        Contact(id: id, firstName: first_name, lastName: last_name,
                username: username, phone: phone ?? "")
    }
}

/// `public.invites`.
struct InviteRow: Codable, Sendable {
    var id: String
    var from_user: String
    var to_user: String
    var status: String
}

/// `public.locations`.
struct LocationRow: Codable, Sendable {
    var user_id: String
    var latitude: Double
    var longitude: Double
    var course: Double?
    var speed: Double?
    var updated_at: Date
}
