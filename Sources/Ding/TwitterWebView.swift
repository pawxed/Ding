import SwiftUI
import WebKit

@available(iOS 13.0, *)
struct TwitterWebView: View {
    var body: some View {
        WebView(url: URL(string: "https://x.com")!)
            .navigationBarTitle("Twitter Web", displayMode: .inline)
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let w = WKWebView()
        w.load(URLRequest(url: url))
        return w
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}