import SwiftUI

@available(iOS 13.0, *)
struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @State private var clientId = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Twitter Client ID")) {
                    TextField("Client ID", text: $clientId)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    Button("Save") {
                        store.twitterClientId = clientId
                        store.saveTwitterClientId()
                    }
                }
                Section(header: Text("Data")) {
                    Button("Clear bookmarks") {
                        store.bookmarks = []
                        store.saveBookmarks()
                    }
                    Button("Clear likes") {
                        store.liked = []
                        store.interests = []
                        store.persistLiked()
                    }
                }
                Section(header: Text("Accounts")) {
                    ForEach(store.accounts) { acc in
                        HStack {
                            Text(acc.source.label)
                            Spacer()
                            Text(acc.handle).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationBarTitle("Settings")
            .onAppear { clientId = store.twitterClientId }
        }
        .navigationViewStyle(.stack)
    }
}