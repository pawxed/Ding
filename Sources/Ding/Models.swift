import Foundation

enum Source: String, Codable, CaseIterable, Identifiable {
    case mastodon, bluesky, twitter
    var id: String { rawValue }
    var label: String {
        switch self { case .mastodon: return "Mastodon"; case .bluesky: return "Bluesky"; case .twitter: return "Twitter" }
    }
    var symbol: String {
        switch self { case .mastodon: return "globe"; case .bluesky: return "cloud"; case .twitter: return "bird" }
    }
}

struct Account: Codable, Identifiable, Hashable {
    let id: UUID
    var source: Source
    var displayName: String
    var handle: String
    var token: String
    var baseURL: String?   // mastodon instance
    var secret: String?    // bluesky app password / twitter secret
}

struct Post: Identifiable, Hashable {
    let id: String
    let source: Source
    let author: String
    let handle: String
    let avatarURL: URL?
    let text: String
    let date: Date
    let likeCount: Int
    let replyCount: Int
}

// MARK: - JSON helpers

enum JSON {
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
    static func date(_ s: String?) -> Date {
        guard let s else { return Date() }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s) ?? Date()
    }
}