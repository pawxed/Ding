import SwiftUI
import SafariServices

@available(iOS 13.0, *)
struct TwitterWebView: View {
    var body: some View {
        SafariView(url: URL(string: "https://x.com")!)
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}