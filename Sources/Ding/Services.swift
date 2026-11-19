import Foundation

enum APIError: Error, LocalizedError {
    case badStatus(Int, String)
    case decode(String)
    var errorDescription: String? {
        switch self {
        case .badStatus(let c, let m): return "HTTP \(c): \(m)"
        case .decode(let m): return "Decode: \(m)"
        }
    }
}

struct HTTP {
    static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 20
        c.waitsForConnectivity = true
        c.urlCache = URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 32 * 1024 * 1024)
        return URLSession(configuration: c)
    }()
    static func request(_ url: URL, method: String = "GET", token: String? = nil, json: Any? = nil) -> URLRequest {
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let json {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try? JSONSerialization.data(withJSONObject: json)
        }
        return r
    }
    static func send(_ r: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, resp) = try await session.data(for: r)
        guard let http = resp as? HTTPURLResponse else { throw APIError.badStatus(0, "no response") }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return (data, http)
    }
}

// MARK: - Mastodon

struct MastodonAPI {
    let base: String
    let token: String
    private var root: String { base.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }

    func home(limit: Int = 30) async throws -> [Post] {
        let url = URL(string: "\(root)/api/v1/timelines/home?limit=\(limit)")!
        let (data, _) = try await HTTP.send(HTTP.request(url, token: token))
        let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return arr.compactMap { parse($0) }
    }
    private func parse(_ s: [String: Any]) -> Post? {
        guard let id = s["id"] as? String,
              let created = s["created_at"] as? String,
              let account = s["account"] as? [String: Any] else { return nil }
        let name = (account["display_name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? account["username"] as? String ?? "user"
        let handle = "@\(account["username"] as? String ?? "")"
        let avatar = (account["avatar"] as? String).flatMap(URL.init(string:))
        let text = stripHTML(s["content"] as? String ?? "")
        return Post(id: "m:\(id)", source: .mastodon, author: name, handle: handle,
                   avatarURL: avatar, text: text, date: JSON.date(created),
                   likeCount: s["favourites_count"] as? Int ?? 0,
                   replyCount: s["replies_count"] as? Int ?? 0)
    }
    func post(_ text: String) async throws {
        let url = URL(string: "\(root)/api/v1/statuses")!
        var r = HTTP.request(url, method: "POST", token: token, json: ["status": text])
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await HTTP.send(r)
    }
}

// MARK: - Bluesky

struct BlueskySession {
    let did: String
    let handle: String
    let accessJwt: String
}

struct BlueskyAPI {
    static let host = "https://bsky.social"

    static func login(identifier: String, password: String) async throws -> BlueskySession {
        let url = URL(string: "\(host)/xrpc/com.atproto.server.createSession")!
        let (data, _) = try await HTTP.send(HTTP.request(url, method: "POST", json: [
            "identifier": identifier, "password": password]))
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let did = o["did"] as? String,
              let handle = o["handle"] as? String,
              let jwt = o["accessJwt"] as? String else { throw APIError.decode("session") }
        return BlueskySession(did: did, handle: handle, accessJwt: jwt)
    }

    let session: BlueskySession
    func home(limit: Int = 30) async throws -> [Post] {
        var comps = URLComponents(string: "\(Self.host)/xrpc/app.bsky.feed.getTimeline")!
        comps.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        let (data, _) = try await HTTP.send(HTTP.request(comps.url!, token: session.accessJwt))
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let feed = o["feed"] as? [[String: Any]] else { throw APIError.decode("feed") }
        return feed.compactMap { item in
            guard let p = item["post"] as? [String: Any],
                  let uri = p["uri"] as? String,
                  let author = p["author"] as? [String: Any],
                  let record = p["record"] as? [String: Any] else { return nil }
            let handle = "@\(author["handle"] as? String ?? "")"
            let name = (author["displayName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? author["handle"] as? String ?? "user"
            let avatar = (author["avatar"] as? String).flatMap(URL.init(string:))
            let text = record["text"] as? String ?? ""
            let created = record["createdAt"] as? String
            return Post(id: "b:\(uri)", source: .bluesky, author: name, handle: handle,
                       avatarURL: avatar, text: text, date: JSON.date(created),
                       likeCount: p["likeCount"] as? Int ?? 0,
                       replyCount: p["replyCount"] as? Int ?? 0)
        }
    }
    func post(_ text: String) async throws {
        let url = URL(string: "\(Self.host)/xrpc/com.atproto.repo.createRecord")!
        let record: [String: Any] = [
            "$type": "app.bsky.feed.post",
            "text": text,
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]
        let body: [String: Any] = [
            "repo": session.did,
            "collection": "app.bsky.feed.post",
            "record": record
        ]
        _ = try await HTTP.send(HTTP.request(url, method: "POST", token: session.accessJwt, json: body))
    }
}

// MARK: - Twitter

struct TwitterAPI {
    let token: String
    private let host = "https://api.twitter.com"

    func me() async throws -> String {
        let url = URL(string: "\(host)/2/users/me")!
        let (data, _) = try await HTTP.send(HTTP.request(url, token: token))
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let d = o["data"] as? [String: Any],
              let id = d["id"] as? String else { throw APIError.decode("me") }
        return id
    }

    func home(limit: Int = 30) async throws -> [Post] {
        let userId = try await me()
        var comps = URLComponents(string: "\(host)/2/users/\(userId)/tweets")!
        comps.queryItems = [
            URLQueryItem(name: "max_results", value: String(min(limit, 100))),
            URLQueryItem(name: "tweet.fields", value: "created_at,public_metrics"),
            URLQueryItem(name: "expansions", value: "author_id"),
            URLQueryItem(name: "user.fields", value: "name,username,profile_image_url")
        ]
        let (data, _) = try await HTTP.send(HTTP.request(comps.url!, token: token))
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw APIError.decode("tweets") }
        let users = (o["includes"] as? [String: Any])?["users"] as? [[String: Any]] ?? []
        let userMap = Dictionary(uniqueKeysWithValues: users.compactMap { u -> (String, [String: Any])? in
            guard let id = u["id"] as? String else { return nil }; return (id, u) })
        let tweets = o["data"] as? [[String: Any]] ?? []
        return tweets.compactMap { t in
            guard let id = t["id"] as? String else { return nil }
            let authorId = t["author_id"] as? String ?? ""
            let u = userMap[authorId]
            let name = u?["name"] as? String ?? "user"
            let handle = "@\(u?["username"] as? String ?? "")"
            let avatar = (u?["profile_image_url"] as? String).flatMap(URL.init(string:))
            let metrics = t["public_metrics"] as? [String: Any]
            return Post(id: "t:\(id)", source: .twitter, author: name, handle: handle,
                       avatarURL: avatar, text: t["text"] as? String ?? "",
                       date: JSON.date(t["created_at"] as? String),
                       likeCount: metrics?["like_count"] as? Int ?? 0,
                       replyCount: metrics?["reply_count"] as? Int ?? 0)
        }
    }

    func post(_ text: String) async throws {
        let url = URL(string: "\(host)/2/tweets")!
        _ = try await HTTP.send(HTTP.request(url, method: "POST", token: token, json: ["text": text]))
    }
}

// MARK: - HTML strip

func stripHTML(_ s: String) -> String {
    var out = s
    // remove tags
    while let r = out.range(of: "<[^>]+>", options: .regularExpression) { out.removeSubrange(r) }
    // common entities
    out = out.replacingOccurrences(of: "&amp;", with: "&")
    out = out.replacingOccurrences(of: "&lt;", with: "<")
    out = out.replacingOccurrences(of: "&gt;", with: ">")
    out = out.replacingOccurrences(of: "&quot;", with: "\"")
    out = out.replacingOccurrences(of: "&#39;", with: "'")
    out = out.replacingOccurrences(of: "&nbsp;", with: " ")
    return out.trimmingCharacters(in: .whitespacesAndNewlines)
}