import SwiftUI
import Combine

@MainActor
final class Store: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var posts: [Post] = []
    @Published var loading = false
    @Published var error: String?

    private let accountsKey = "ding.accounts"

    init() {
        loadAccounts()
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
                // token stored as accessJwt; secret holds password for relogin? We store accessJwt in token.
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
}