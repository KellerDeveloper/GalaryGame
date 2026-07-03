import Foundation

/// Supabase connection settings for the opt-in cloud leaderboard.
///
/// The anon (publishable) key is safe to ship in the client by design — row
/// access is enforced server-side by RLS (see `supabase/migrations`). Fill these
/// in with your project's values; until then `isConfigured` is false and the
/// `LeaderboardService` no-ops so the rest of the app runs normally.
enum SupabaseConfig {
    /// e.g. "https://abcdefgh.supabase.co"
    static let url = ""
    /// Project anon/publishable key.
    static let anonKey = ""

    static var isConfigured: Bool {
        !url.isEmpty && !anonKey.isEmpty
    }

    /// REST base for the leaderboard table.
    static var restURL: URL? {
        guard isConfigured else { return nil }
        return URL(string: "\(url)/rest/v1/leaderboard")
    }
}
