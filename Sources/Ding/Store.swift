import SwiftUI
import Combine

@available(iOS 13.0, *)
@MainActor
final class Store: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var posts: [Post] = []
    @Published var loading = false
    @Published var error: String?
    @Published var twitterClientId: String = UserDefaults.standard.string(forKey: "ding.twitterClientId") ?? ""
    @Published var liked: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "ding.liked") ?? [])
    @Published var interests: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "ding.interests") ?? [])
    @Published var bookmarks: [Post] = []
    @Published var searchResults: [Post] = []
    @Published var notifications: [String] = []
    @Published var profileName: String = ""
    @Published var replyTarget: Post? = nil
    @Published var searchText: String = ""

    private let accountsKey = "ding.accounts"

    init() {
        loadAccounts()
        loadBookmarks()
    }
    func loadBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: "ding.bookmarks"),
              let decoded = try? JSONDecoder().decode([Post].self, from: data) else { return }
        bookmarks = decoded
    }
    func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: "ding.bookmarks")
        }
    }

    func loadAccounts() {
        guard let data = UserDefaults.standard.data(forKey: accountsKey),
              let decoded = try? JSONDecoder().decode([Account].self, from: data) else { return }
        accounts = decoded
    }

    func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
    }
    func saveTwitterClientId() {
        UserDefaults.standard.set(twitterClientId, forKey: "ding.twitterClientId")
    }
    func persistLiked() {
        UserDefaults.standard.set(Array(liked), forKey: "ding.liked")
        UserDefaults.standard.set(Array(interests), forKey: "ding.interests")
    }

    func add(_ account: Account) {
        accounts.removeAll { $0.source == account.source && $0.handle == account.handle }
        accounts.append(account)
        saveAccounts()
    }

    func remove(_ account: Account) {
        accounts.removeAll { $0.id == account.id }
        saveAccounts()
    }

    func refresh() async {
        loading = true
        error = nil
        var collected: [Post] = []
        await withTaskGroup(of: [Post].self) { group in
            for account in accounts {
                group.addTask { await Self.fetch(account) }
            }
            for await batch in group {
                collected.append(contentsOf: batch)
            }
        }
        collected.sort { $0.date > $1.date }
        posts = collected
        loading = false
    }

    nonisolated private static func fetch(_ account: Account) async -> [Post] {
        do {
            switch account.source {
            case .mastodon:
                guard let base = account.baseURL else { return [] }
                return try await MastodonAPI(base: base, token: account.token).home()
            case .bluesky:
                
                let session = BlueskySession(did: account.secret ?? "", handle: account.handle, accessJwt: account.token)
                return try await BlueskyAPI(session: session).home()
            case .twitter:
                return try await TwitterAPI(token: account.token).home()
            }
        } catch {
            return []
        }
    }

    func compose(_ text: String, source: Source) async -> Bool {
        guard let account = accounts.first(where: { $0.source == source }) else { return false }
        do {
            switch source {
            case .mastodon:
                guard let base = account.baseURL else { return false }
                try await MastodonAPI(base: base, token: account.token).post(text)
            case .bluesky:
                let session = BlueskySession(did: account.secret ?? "", handle: account.handle, accessJwt: account.token)
                try await BlueskyAPI(session: session).post(text)
            case .twitter:
                try await TwitterAPI(token: account.token).post(text)
            }
            await refresh()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func loginTwitter(clientId: String) async -> Bool {
        twitterClientId = clientId
        saveTwitterClientId()
        do {
            let token = try await TwitterOAuth(clientId: clientId).signIn()
            let api = TwitterAPI(token: token)
            let id = try await api.me()
            let acc = Account(id: UUID(), source: .twitter, displayName: "Twitter", handle: "@\(id)", token: token, baseURL: nil, secret: nil)
            add(acc)
            await refresh()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func crosspost(_ text: String, sources: [Source]) async -> Bool {
        var ok = true
        for s in sources {
            let r = await compose(text, source: s)
            if !r { ok = false }
        }
        return ok
    }

    func toggleLike(_ post: Post) {
        if liked.contains(post.id) {
            liked.remove(post.id)
        } else {
            liked.insert(post.id)
            
            let words = post.text.lowercased().split { !$0.isLetter && !$0.isNumber }
            for w in words where w.count > 3 {
                interests.insert(String(w))
            }
        }
        persistLiked()
    }

    var forYouPosts: [Post] {
        let now = Date()
        func score(_ p: Post) -> Double {
            let age = now.timeIntervalSince(p.date)
            var s = -age / 3600.0  
            let words = p.text.lowercased().split { !$0.isLetter && !$0.isNumber }
            let matches = words.filter { interests.contains(String($0)) }.count
            s += Double(matches) * 5.0
            if liked.contains(p.id) { s += 20.0 }
            
            return s
        }
        return posts.sorted { score($0) > score($1) }
    }
    func like(_ post: Post) async {
        guard let account = accounts.first(where: { $0.source == post.source }) else { return }
        do {
            switch post.source {
            case .mastodon:
                guard let base = account.baseURL else { return }
                try await MastodonAPI(base: base, token: account.token).favourite(String(post.id.dropFirst(2)))
            case .bluesky:
                break
            case .twitter:
                let userId = try await TwitterAPI(token: account.token).me()
                try await TwitterAPI(token: account.token).like(tweetId: String(post.id.dropFirst(2)), userId: userId)
            }
            toggleLike(post)
        } catch { self.error = error.localizedDescription }
    }

    func repost(_ post: Post) async {
        guard let account = accounts.first(where: { $0.source == post.source }) else { return }
        do {
            switch post.source {
            case .mastodon:
                guard let base = account.baseURL else { return }
                try await MastodonAPI(base: base, token: account.token).reblog(String(post.id.dropFirst(2)))
            case .bluesky:
                break
            case .twitter:
                let userId = try await TwitterAPI(token: account.token).me()
                try await TwitterAPI(token: account.token).retweet(tweetId: String(post.id.dropFirst(2)), userId: userId)
            }
            await refresh()
        } catch { self.error = error.localizedDescription }
    }

    func deletePost(_ post: Post) async {
        guard let account = accounts.first(where: { $0.source == post.source }) else { return }
        do {
            switch post.source {
            case .mastodon:
                guard let base = account.baseURL else { return }
                try await MastodonAPI(base: base, token: account.token).deleteStatus(String(post.id.dropFirst(2)))
            case .bluesky:
                break
            case .twitter:
                try await TwitterAPI(token: account.token).deleteTweet(String(post.id.dropFirst(2)))
            }
            posts.removeAll { $0.id == post.id }
        } catch { self.error = error.localizedDescription }
    }

    func reply(_ text: String, to post: Post) async -> Bool {
        guard let account = accounts.first(where: { $0.source == post.source }) else { return false }
        do {
            switch post.source {
            case .mastodon:
                guard let base = account.baseURL else { return false }
                try await MastodonAPI(base: base, token: account.token).reply(text, to: String(post.id.dropFirst(2)))
            case .bluesky:
                break
            case .twitter:
                try await TwitterAPI(token: account.token).reply(text, to: String(post.id.dropFirst(2)))
            }
            replyTarget = nil
            await refresh()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func search(_ query: String) async {
        searchText = query
        var collected: [Post] = []
        await withTaskGroup(of: [Post].self) { group in
            for account in accounts {
                group.addTask {
                    do {
                        switch account.source {
                        case .mastodon:
                            guard let base = account.baseURL else { return [] }
                            return try await MastodonAPI(base: base, token: account.token).search(query)
                        case .bluesky:
                            let session = BlueskySession(did: account.secret ?? "", handle: account.handle, accessJwt: account.token)
                            return try await BlueskyAPI(session: session).search(query)
                        case .twitter:
                            return try await TwitterAPI(token: account.token).search(query)
                        }
                    } catch { return [] }
                }
            }
            for await batch in group { collected.append(contentsOf: batch) }
        }
        collected.sort { $0.date > $1.date }
        searchResults = collected
    }

    func loadNotifications() async {
        var collected: [String] = []
        for account in accounts {
            do {
                switch account.source {
                case .mastodon:
                    guard let base = account.baseURL else { continue }
                    collected.append(contentsOf: try await MastodonAPI(base: base, token: account.token).notifications())
                case .bluesky:
                    let session = BlueskySession(did: account.secret ?? "", handle: account.handle, accessJwt: account.token)
                    collected.append(contentsOf: try await BlueskyAPI(session: session).notifications())
                case .twitter:
                    break
                }
            } catch {}
        }
        notifications = collected
    }

    func loadProfile() async {
        if let account = accounts.first {
            do {
                switch account.source {
                case .mastodon:
                    guard let base = account.baseURL else { return }
                    profileName = try await MastodonAPI(base: base, token: account.token).verifyCredentials()
                case .bluesky:
                    let session = BlueskySession(did: account.secret ?? "", handle: account.handle, accessJwt: account.token)
                    profileName = try await BlueskyAPI(session: session).getProfile()
                case .twitter:
                    profileName = account.handle
                }
            } catch { profileName = account.handle }
        }
    }

    func toggleBookmark(_ post: Post) {
        if let idx = bookmarks.firstIndex(where: { $0.id == post.id }) {
            bookmarks.remove(at: idx)
        } else {
            bookmarks.append(post)
        }
        saveBookmarks()
    }

    func isBookmarked(_ post: Post) -> Bool {
        bookmarks.contains { $0.id == post.id }
    }}