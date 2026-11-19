import SwiftUI

@available(iOS 13.0, *)
struct BookmarksView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        NavigationView {
            Group {
                if store.bookmarks.isEmpty {
                    VStack {
                        Image(systemName: "bookmark").font(.largeTitle).foregroundColor(.secondary)
                        Text("No bookmarks").font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(store.bookmarks) { post in
                        PostRow(post: post)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationBarTitle("Bookmarks")
        }
        .navigationViewStyle(.stack)
    }
}