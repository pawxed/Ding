import SwiftUI

@available(iOS 13.0, *)
struct ThreadView: View {
    @EnvironmentObject private var store: Store
    let post: Post
    @State private var replyText = ""
    @State private var sending = false

    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    PostRow(post: post)
                        .padding()
                }
                HStack {
                    TextView(text: $replyText)
                        .frame(height: 60)
                    Button("Reply") {
                        sending = true
                        Task {
                            _ = await store.reply(replyText, to: post)
                            replyText = ""
                            sending = false
                        }
                    }
                    .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
                }
                .padding()
            }
            .navigationBarTitle("Thread")
        }
        .navigationViewStyle(.stack)
    }
}