import SwiftUI

@available(iOS 13.0, *)
struct SearchView: View {
    @EnvironmentObject private var store: Store
    @State private var query = ""

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Search", text: $query)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Go") { Task { await store.search(query) } }
                }
                .padding()
                List(store.searchResults) { post in
                    PostRow(post: post)
                }
                .listStyle(.plain)
            }
            .navigationBarTitle("Search")
        }
        .navigationViewStyle(.stack)
    }
}