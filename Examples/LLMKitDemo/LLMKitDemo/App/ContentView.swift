import LLMUIDownloads
import SwiftUI

struct ContentView: View {
    @State private var viewModel: DemoViewModel
    @State private var downloadsViewModel: ModelDownloadsViewModel
    @State private var selectedTab = 0

    private let configuration: DemoRuntimeConfiguration

    init(configuration: DemoRuntimeConfiguration = DemoConfiguration.make()) {
        self.configuration = configuration
        self._viewModel = State(initialValue: DemoViewModel(configuration: configuration))
        self._downloadsViewModel = State(
            initialValue: ModelDownloadsViewModel(
                descriptors: configuration.downloadableModels,
                lifecycleService: configuration.container.lifecycle
            )
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ChatSessionsTab(
                viewModel: viewModel,
                configuration: configuration,
                openModels: {
                    selectedTab = 1
                }
            )
            .tabItem {
                Label("Chat", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(0)

            ModelsTab(
                viewModel: viewModel,
                downloadsViewModel: downloadsViewModel
            )
            .tabItem {
                Label("Models", systemImage: "cpu")
            }
            .tag(1)

            SettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .tint(.blue)
        .task {
            await refreshAll()
        }
    }

    private func refreshAll() async {
        await viewModel.refresh()
        downloadsViewModel.updateDescriptors(viewModel.downloadableModels)
        await downloadsViewModel.refresh()
    }
}

#Preview {
    ContentView(configuration: DemoConfiguration.preview())
}
