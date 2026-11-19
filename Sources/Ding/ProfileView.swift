import SwiftUI

@available(iOS 13.0, *)
struct ProfileView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill").font(.system(size: 64)).foregroundColor(.secondary)
                Text(store.profileName.isEmpty ? "No account" : store.profileName).font(.headline)
                Text("\(store.accounts.count) accounts").font(.caption).foregroundColor(.secondary)
                Button("Refresh profile") { Task { await store.loadProfile() } }
                Spacer()
            }
            .padding()
            .navigationBarTitle("Profile")
        }
        .navigationViewStyle(.stack)
        .onAppear { Task { await store.loadProfile() } }
    }
}