import LLMCore
import LLMUIDownloads
import SwiftUI

struct ContentView: View {
    @State private var viewModel = DemoViewModel()
    @State private var prompt = "Explain what LLMKit is doing here."

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusBar
                Divider()
                messageList
                Divider()
                composer
            }
            .navigationTitle("LLMKit Demo")
            .toolbar {
                Button("Install Demo Model") {
                    Task { await viewModel.installDemoModel() }
                }
            }
        }
    }

    private var statusBar: some View {
        HStack {
            ModelInstallProgressView(state: viewModel.installState)
            Spacer()
            Text(viewModel.isSending ? "Streaming" : "Ready")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var messageList: some View {
        List(viewModel.messages) { message in
            VStack(alignment: .leading, spacing: 4) {
                Text(message.role.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(message.content.text)
            }
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message", text: $prompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)

            Button("Send") {
                let text = prompt
                prompt = ""
                Task { await viewModel.send(text) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
