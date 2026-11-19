import SwiftUI

@available(iOS 13.0, *)
struct ComposeView: View {
    @EnvironmentObject private var store: Store
    @State private var text = ""
    @State private var source: Source = .mastodon
    @State private var posting = false
    @State private var result: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account")) {
                    Picker("Post to", selection: $source) {
                        ForEach(Source.allCases) { s in Text(s.label).tag(s) }
                    }
                    .pickerStyle(.segmented)
                }
                Section(header: Text("Message")) {
                    TextView(text: $text)
                        .frame(minHeight: 120)
                }
                Section {
                    Button {
                        posting = true
                        Task {
                            let ok = await store.compose(text, source: source)
                            posting = false
                            if ok { text = ""; result = "Posted" } else { result = store.error ?? "Failed" }
                        }
                    } label: {
                        HStack {
                            if posting { Text("…").font(.caption) }
                            Text(posting ? "Posting…" : "Post")
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || posting)
                }
                if let result {
                    Section { Text(result).font(.caption).foregroundColor(.secondary) }
                }
            }
            .navigationBarTitle("Compose")
        }
        .navigationViewStyle(.stack)
    }
}

@available(iOS 13.0, *)
struct TextView: UIViewRepresentable {
    @Binding var text: String
    func makeUIView(context: Context) -> UITextView {
        let v = UITextView()
        v.font = UIFont.preferredFont(forTextStyle: .body)
        v.backgroundColor = .clear
        v.delegate = context.coordinator
        return v
    }
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextView
        init(_ parent: TextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
    }
}