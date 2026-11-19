import SwiftUI

@available(iOS 13.0, *)
struct FeedView: View {
    static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
    @EnvironmentObject private var store: Store

    var body: some View {
        NavigationView {
            Group {
                if store.posts.isEmpty && !store.loading {
                    VStack(spacing: 12) {
                        Image(systemName: "tray").font(.largeTitle).foregroundColor(.secondary)
                        Text("No posts").font(.headline)
                        Text("Add an account in Accounts, then tap Refresh.").font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(store.posts) { post in
                        PostRow(post: post)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationBarTitle("Ding")
            .navigationBarItems(trailing:
                Group {
                    if store.loading { Text("Loading…").font(.caption) }
                    else {
                        Button(action: { Task { await store.refresh() } }) { Image(systemName: "arrow.clockwise") }
                    }
                }
            )
        }
        .navigationViewStyle(.stack)
        .onAppear { if store.posts.isEmpty { Task { await store.refresh() } } }
    }
}

@available(iOS 13.0, *)
struct PostRow: View {
    let post: Post
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CachedImage(url: post.avatarURL)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(post.author).font(.headline)
                    Text(post.handle).font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: post.source.symbol).font(.caption).foregroundColor(.secondary)
                }
                Text(post.text).font(.body).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 16) {
                    HStack(spacing: 2) { Image(systemName: "bubble.left").font(.caption); Text("\(post.replyCount)").font(.caption) }
                    HStack(spacing: 2) { Image(systemName: "heart").font(.caption); Text("\(post.likeCount)").font(.caption) }
                    Text(Self.dateFmt.string(from: post.date)).font(.caption).foregroundColor(.secondary)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}