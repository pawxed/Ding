import SwiftUI

@available(iOS 13.0, *)
struct AccountsView: View {
    @EnvironmentObject private var store: Store

    
    @State private var mBase = "https://woof.tech"
    @State private var mToken = ""
    
    @State private var bIdent = ""
    @State private var bPass = ""
    
    @State private var tToken = ""

    @State private var busy = false
    @State private var message: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Mastodon")) {
                    TextField("Instance URL", text: $mBase)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    SecureField("Access token", text: $mToken)
                    Button("Add Mastodon account") {
                        Task { await addMastodon() }
                    }
                    .disabled(mToken.isEmpty || busy)
                }
                Section(header: Text("Bluesky")) {
                    TextField("Handle or email", text: $bIdent)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    SecureField("App password", text: $bPass)
                    Button("Sign in to Bluesky") {
                        Task { await addBluesky() }
                    }
                    .disabled(bIdent.isEmpty || bPass.isEmpty || busy)
                }
                Section(header: Text("Twitter / X (token)")) {
                    SecureField("Bearer / user token", text: $tToken)
                    Button("Add Twitter account") {
                        Task { await addTwitter() }
                    }
                    .disabled(tToken.isEmpty || busy)
                }
                Section(header: Text("Connected")) {
                    if store.accounts.isEmpty {
                        Text("None yet").foregroundColor(.secondary)
                    } else {
                        ForEach(store.accounts) { acc in
                            HStack {
                                Image(systemName: acc.source.symbol)
                                VStack(alignment: .leading) {
                                    Text(acc.displayName).font(.headline)
                                    Text(acc.handle).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(acc.source.label).font(.caption).foregroundColor(.secondary)
                            }
                            Button(action: { store.remove(acc) }) { Image(systemName: "trash").foregroundColor(.red) }
                        }
                    }
                }
                if let message {
                    Section { Text(message).font(.caption).foregroundColor(.secondary) }
                }
            }
            .navigationBarTitle("Accounts", displayMode: .inline)
        }
        .navigationViewStyle(.stack)
    }

    private func addMastodon() async {
        busy = true; defer { busy = false }
        let acc = Account(id: UUID(), source: .mastodon, displayName: "Mastodon", handle: mBase, token: mToken, baseURL: mBase, secret: nil)
        store.add(acc)
        mToken = ""
        message = "Mastodon account added."
        await store.refresh()
    }

    private func addBluesky() async {
        busy = true; defer { busy = false }
        do {
            let s = try await BlueskyAPI.login(identifier: bIdent, password: bPass)
            let acc = Account(id: UUID(), source: .bluesky, displayName: s.handle, handle: "@\(s.handle)", token: s.accessJwt, baseURL: nil, secret: s.did)
            store.add(acc)
            bPass = ""
            message = "Bluesky signed in."
            await store.refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    private func addTwitter() async {
        busy = true; defer { busy = false }
        do {
            let api = TwitterAPI(token: tToken)
            let id = try await api.me()
            let acc = Account(id: UUID(), source: .twitter, displayName: "Twitter", handle: "@\(id)", token: tToken, baseURL: nil, secret: nil)
            store.add(acc)
            tToken = ""
            message = "Twitter account added."
            await store.refresh()
        } catch {
            message = error.localizedDescription
        }
    }

}