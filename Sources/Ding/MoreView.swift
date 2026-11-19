import SwiftUI

@available(iOS 13.0, *)
struct MoreView: View {
    @State private var selection: Int = 0

    var body: some View {
        NavigationView {
            List {
                NavigationLink("For You") { FYPView() }
                NavigationLink("Bookmarks") { BookmarksView() }
                NavigationLink("Profile") { ProfileView() }
                NavigationLink("Accounts") { AccountsView() }
                NavigationLink("Settings") { SettingsView() }
            }
            .listStyle(.plain)
            .navigationBarTitle("More")
        }
        .navigationViewStyle(.stack)
    }
}