import SwiftUI

struct ComposeView: View {
    @EnvironmentObject private var store: Store
    @State private var text = ""
    @State private var selected: Set<Source> = []
    @State private var posting = false
    @State private var result: String?

    var connectedSources: [Source] {
        Array(Set(store.accounts.map { $0.source })).sorted { $0.label < $1.label }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Post to")) {
                    ForEach(connectedSources) { s in
                        Toggle(s.label, isOn: Binding(
                            get: { selected.contains(s) },
                            set: { on in if on { selected.insert(s) } else { selected.remove(s) } }
                        ))
                    }
                    if connectedSources.isEmpty {
                        Text("No accounts connected.").foregroundColor(.secondary)
                    }
                }
                Section(header: Text("Message")) {
                    TextView(text: $text)
                        .frame(minHeight: 120)
                }
                Section {
                    Button {
                        posting = true
                        Task {
                            let ok = await store.crosspost(text, sources: Array(selected))
                            posting = false
                            if ok { text = ""; result = "Posted" } else { result = store.error ?? "Failed" }
                        }
                    } label: {
                        HStack {
                            if posting { Text("…").font(.caption) }
                            Text(posting ? "Posting…" : "Post")
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selected.isEmpty || posting)
                }
                if let result {
                    Section { Text(result).font(.caption).foregroundColor(.secondary) }
                }
            }
            .navigationBarTitle("Compose")
            .onAppear {
                if selected.isEmpty { selected = Set(connectedSources) }
            }
        }
        .navigationViewStyle(.stack)
    }
}

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