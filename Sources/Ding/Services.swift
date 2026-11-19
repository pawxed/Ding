import Foundation
import AuthenticationServices
import CryptoKit

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

@available(iOS 13.0, *)
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



@available(iOS 13.0, *)
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
    func favourite(_ id: String) async throws {
        let url = URL(string: "\(root)/api/v1/statuses/\(id)/favourite")!
        _ = try await HTTP.send(HTTP.request(url, method: "POST", token: token))
    }
    func unfavourite(_ id: String) async throws {
        let url = URL(string: "\(root)/api/v1/statuses/\(id)/unfavourite")!
        _ = try await HTTP.send(HTTP.request(url, method: "POST", token: token))
    }
    func reblog(_ id: String) async throws {
        let url = URL(string: "\(root)/api/v1/statuses/\(id)/reblog")!
        _ = try await HTTP.send(HTTP.request(url, method: "POST", token: token))
    }
    func unreblog(_ id: String) async throws {
        let url = URL(string: "\(root)/api/v1/statuses/\(id)/unreblog")!
        _ = try await HTTP.send(HTTP.request(url, method: "POST", token: token))
    }
    func deleteStatus(_ id: String) async throws {
        let url = URL(string: "\(root)/api/v1/statuses/\(id)")!
        _ = try await HTTP.send(HTTP.request(url, method: "DELETE", token: token))
    }
    func reply(_ text: String, to id: String) async throws {
        let url = URL(string: "\(root)/api/v1/statuses")!
        _ = try await HTTP.send(HTTP.request(url, method: "POST", token: token, json: ["status": text, "in_reply_to_id": id]))
    }
    func search(_ query: String) async throws -> [Post] {
        var comps = URLComponents(string: "\(root)/api/v2/search")!
        comps.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "type", value: "statuses"), URLQueryItem(name: "limit", value: "20")]
        let (data, _) = try await HTTP.send(HTTP.request(comps.url!, token: token))
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let statuses = o["statuses"] as? [[String: Any]] else { return [] }
        return statuses.compactMap { parse($0) }
    }
    func notifications() async throws -> [String] {
        let url = URL(string: "\(root)/api/v1/notifications?limit=30")!
        let (data, _) = try await HTTP.send(HTTP.request(url, token: token))
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { $0["type"] as? String }
    }
    func verifyCredentials() async throws -> String {
        let url = URL(string: "\(root)/api/v1/accounts/verify_credentials")!
        let (data, _) = try await HTTP.send(HTTP.request(url, token: token))
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "me" }
        return (o["display_name"] as? String) ?? (o["username"] as? String) ?? "me"
    }}



@available(iOS 13.0, *)
struct BlueskySession {
    let did: String
    let handle: String
    let accessJwt: String
}

@available(iOS 13.0, *)
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
    func like(uri: String, cid: String) async throws {
        let url = URL(string: "\(Self.host)/xrpc/com.atproto.repo.createRecord")!
        let body: [String: Any] = [
            "repo": session.did,
            "collection": "app.bsky.feed.like",
            "record": [
                "$type": "app.bsky.feed.like",
                "subject": ["uri": uri, "cid": cid],
                "createdAt": ISO8601DateFormatter().string(from: Date())
            ]
        ]
        _ = try await HTTP.send(HTTP.request(url, method: "POST", token: session.accessJwt, json: body))
    }
    func repost(uri: String, cid: String) async throws {
        let url = URL(string: "\(Self.host)/xrpc/com.atproto.repo.createRecord")!
        let body: [String: Any] = [
            "repo": session.did,
            "collection": "app.bsky.feed.repost",
            "record": [
                "$type": "app.bsky.feed.repost",
                "subject": ["uri": uri, "cid": cid],
                "createdAt": ISO8601DateFormatter().string(from: Date())
            ]
        ]
        _ = try await HTTP.send(HTTP.request(url, method: "POST", token: session.accessJwt, json: body))
    }
    func deleteRecord(collection: String, rkey: String) async throws {
        let url = URL(string: "\(Self.host)/xrpc/com.atproto.repo.deleteRecord")!
        let body: [String: Any] = ["repo": session.did, "collection": collection, "rkey": rkey]
        _ = try await HTTP.send(HTTP.request(url, method: "POST", token: session.accessJwt, json: body))
    }
    func search(_ query: String) async throws -> [Post] {
        var comps = URLComponents(string: "\(Self.host)/xrpc/app.bsky.feed.searchPosts")!
        comps.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "limit", value: "20")]
        let (data, _) = try await HTTP.send(HTTP.request(comps.url!, token: session.accessJwt))
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let posts = o["posts"] as? [[String: Any]] else { return [] }
        return posts.compactMap { p in
            guard let uri = p["uri"] as? String,
                  let author = p["author"] as? [String: Any] else { return nil }
            let handle = "@\(author["handle"] as? String ?? "")"
            let name = (author["displayName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? author["handle"] as? String ?? "user"
            let avatar = (author["avatar"] as? String).flatMap(URL.init(string:))
            let record = p["record"] as? [String: Any]
            return Post(id: "b:\(uri)", source: .bluesky, author: name, handle: handle, avatarURL: avatar, text: record?["text"] as? String ?? "", date: JSON.date(record?["createdAt"] as? String), likeCount: p["likeCount"] as? Int ?? 0, replyCount: p["replyCount"] as? Int ?? 0)
        }
    }
    func notifications() async throws -> [String] {
        var comps = URLComponents(string: "\(Self.host)/xrpc/app.bsky.notification.listNotifications")!
        comps.queryItems = [URLQueryItem(name: "limit", value: "30")]
        let (data, _) = try await HTTP.send(HTTP.request(comps.url!, token: session.accessJwt))
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let notifs = o["notifications"] as? [[String: Any]] else { return [] }
        return notifs.compactMap { $0["reason"] as? String }
    }
    func getProfile() async throws -> String {
        var comps = URLComponents(string: "\(Self.host)/xrpc/app.bsky.actor.getProfile")!
        comps.queryItems = [URLQueryItem(name: "actor", value: session.handle)]
        let (data, _) = try await HTTP.send(HTTP.request(comps.url!, token: session.accessJwt))
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return session.handle }
        return (o["displayName"] as? String) ?? (o["handle"] as? String) ?? session.handle
    }}



@available(iOS 13.0, *)
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
    func like(tweetId: String, userId: String) async throws {
        let url = URL(string: "\(host)/2/users/\(userId)/likes")!
        _ = try await HTTP.send(HTTP.request(url, method: "POST", token: token, json: ["tweet_id": tweetId]))
    }
    func unlike(tweetId: String, userId: String) async throws {
        let url = URL(string: "\(host)/2/users/\(userId)/likes/\(tweetId)")!
        _ = try await HTTP.send(HTTP.request(url, method: "DELETE", token: token))
    }
    func retweet(tweetId: String, userId: String) async throws {
        let url = URL(string: "\(host)/2/users/\(userId)/retweets")!
        _ = try await HTTP.send(HTTP.request(url, method: "POST", token: token, json: ["tweet_id": tweetId]))
    }
    func unretweet(tweetId: String, userId: String) async throws {
        let url = URL(string: "\(host)/2/users/\(userId)/retweets/\(tweetId)")!
        _ = try await HTTP.send(HTTP.request(url, method: "DELETE", token: token))
    }
    func deleteTweet(_ id: String) async throws {
        let url = URL(string: "\(host)/2/tweets/\(id)")!
        _ = try await HTTP.send(HTTP.request(url, method: "DELETE", token: token))
    }
    func reply(_ text: String, to id: String) async throws {
        let url = URL(string: "\(host)/2/tweets")!
        _ = try await HTTP.send(HTTP.request(url, method: "POST", token: token, json: ["text": text, "reply": ["in_reply_to_tweet_id": id]]))
    }
    func search(_ query: String) async throws -> [Post] {
        var comps = URLComponents(string: "\(host)/2/tweets/search/recent")!
        comps.queryItems = [URLQueryItem(name: "query", value: query), URLQueryItem(name: "max_results", value: "20"), URLQueryItem(name: "tweet.fields", value: "created_at,public_metrics"), URLQueryItem(name: "expansions", value: "author_id"), URLQueryItem(name: "user.fields", value: "name,username,profile_image_url")]
        let (data, _) = try await HTTP.send(HTTP.request(comps.url!, token: token))
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let users = (o["includes"] as? [String: Any])?["users"] as? [[String: Any]] ?? []
        let userMap = Dictionary(uniqueKeysWithValues: users.compactMap { u -> (String, [String: Any])? in guard let id = u["id"] as? String else { return nil }; return (id, u) })
        let tweets = o["data"] as? [[String: Any]] ?? []
        return tweets.compactMap { t in
            guard let id = t["id"] as? String else { return nil }
            let authorId = t["author_id"] as? String ?? ""
            let u = userMap[authorId]
            let metrics = t["public_metrics"] as? [String: Any]
            return Post(id: "t:\(id)", source: .twitter, author: u?["name"] as? String ?? "user", handle: "@\(u?["username"] as? String ?? "")", avatarURL: (u?["profile_image_url"] as? String).flatMap(URL.init(string:)), text: t["text"] as? String ?? "", date: JSON.date(t["created_at"] as? String), likeCount: metrics?["like_count"] as? Int ?? 0, replyCount: metrics?["reply_count"] as? Int ?? 0)
        }
    }}



func stripHTML(_ s: String) -> String {
    var out = s
    
    while let r = out.range(of: "<[^>]+>", options: .regularExpression) { out.removeSubrange(r) }
    
    out = out.replacingOccurrences(of: "&amp;", with: "&")
    out = out.replacingOccurrences(of: "&lt;", with: "<")
    out = out.replacingOccurrences(of: "&gt;", with: ">")
    out = out.replacingOccurrences(of: "&quot;", with: "\"")
    out = out.replacingOccurrences(of: "&#39;", with: "'")
    out = out.replacingOccurrences(of: "&nbsp;", with: " ")
    return out.trimmingCharacters(in: .whitespacesAndNewlines)
}



@available(iOS 13.0, *)
final class TwitterOAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    let clientId: String
    let redirectUri = "ding://oauth-callback"
    private var continuation: CheckedContinuation<String, Error>?

    init(clientId: String) { self.clientId = clientId }

    func signIn() async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let verifier = Self.randomString(length: 64)
            let challenge = Self.codeChallenge(for: verifier)
            let state = Self.randomString(length: 16)
            var comps = URLComponents(string: "https://twitter.com/i/oauth2/authorize")!
            comps.queryItems = [
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "client_id", value: clientId),
                URLQueryItem(name: "redirect_uri", value: redirectUri),
                URLQueryItem(name: "scope", value: "tweet.read tweet.write users.read offline.access"),
                URLQueryItem(name: "state", value: state),
                URLQueryItem(name: "code_challenge", value: challenge),
                URLQueryItem(name: "code_challenge_method", value: "S256")
            ]
            let session = ASWebAuthenticationSession(url: comps.url!, callbackURLScheme: "ding") { [weak self] url, error in
                guard let self else { return }
                if let error { self.finish(.failure(error)); return }
                guard let url, let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value else {
                    self.finish(.failure(APIError.decode("no code"))); return
                }
                Task { await self.exchange(code: code, verifier: verifier) }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    private func exchange(code: String, verifier: String) async {
        do {
            let comps = URLComponents(string: "https://api.twitter.com/2/oauth2/token")!
            let body = "grant_type=authorization_code&code=\(code)&redirect_uri=\(redirectUri)&code_verifier=\(verifier)&client_id=\(clientId)"
            var req = URLRequest(url: comps.url!)
            req.httpMethod = "POST"
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            req.httpBody = body.data(using: .utf8)
            let (data, resp) = try await HTTP.session.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw APIError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? 0, String(data: data, encoding: .utf8) ?? "")
            }
            guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = o["access_token"] as? String else { throw APIError.decode("token") }
            finish(.success(token))
        } catch {
            finish(.failure(error))
        }
    }

    private func finish(_ result: Result<String, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first { return window }
        return ASPresentationAnchor()
    }

    static func randomString(length: Int) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    static func codeChallenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}