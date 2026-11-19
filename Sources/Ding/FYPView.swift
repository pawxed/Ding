import SwiftUI

@available(iOS 13.0, *)
struct FYPView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        NavigationView {
            Group {
                if store.forYouPosts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles").font(.largeTitle).foregroundColor(.secondary)
                        Text("For You").font(.headline)
                        Text("Like posts to teach Ding your interests.").font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(store.forYouPosts) { post in
                        PostRow(post: post, liked: store.liked.contains(post.id)) {
                            store.toggleLike(post)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationBarTitle("For You")
        }
        .navigationViewStyle(.stack)
    }
}