import Foundation

/// Minimal, dependency-free Supabase REST client for the opt-in leaderboard.
/// Sends only score data (name + xp + score). No photos, no gallery metadata.
struct LeaderboardService {

    struct Entry: Decodable, Identifiable {
        let playerID: UUID
        let displayName: String
        let xp: Int
        let dosScore: Int

        var id: UUID { playerID }

        enum CodingKeys: String, CodingKey {
            case playerID = "player_id"
            case displayName = "display_name"
            case xp
            case dosScore = "dos_score"
        }
    }

    enum LeaderboardError: Error { case notConfigured, badResponse(Int) }

    private var session: URLSession { .shared }

    private func baseRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    /// Insert or update this player's row (keyed by `player_id`).
    func upsert(playerID: UUID, displayName: String, xp: Int, dosScore: Int) async throws {
        guard SupabaseConfig.isConfigured,
              let base = SupabaseConfig.restURL,
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        else { throw LeaderboardError.notConfigured }
        components.queryItems = [URLQueryItem(name: "on_conflict", value: "player_id")]

        var request = baseRequest(components.url ?? base)
        request.httpMethod = "POST"
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")

        let payload: [[String: Any]] = [[
            "player_id": playerID.uuidString,
            "display_name": displayName,
            "xp": xp,
            "dos_score": dosScore,
            "updated_at": ISO8601DateFormatter().string(from: .now),
        ]]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await session.data(for: request)
        try Self.validate(response)
    }

    /// Fetch the top `limit` players ordered by XP.
    func top(limit: Int = 50) async throws -> [Entry] {
        guard SupabaseConfig.isConfigured,
              let base = SupabaseConfig.restURL,
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        else { throw LeaderboardError.notConfigured }
        components.queryItems = [
            URLQueryItem(name: "select", value: "player_id,display_name,xp,dos_score"),
            URLQueryItem(name: "order", value: "xp.desc"),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        let request = baseRequest(components.url ?? base)
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        return try JSONDecoder().decode([Entry].self, from: data)
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw LeaderboardError.badResponse(-1) }
        guard (200..<300).contains(http.statusCode) else {
            throw LeaderboardError.badResponse(http.statusCode)
        }
    }
}
