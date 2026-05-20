import LLMUIModels
import SwiftUI

struct ContentView: View {
    @State private var viewModel: DemoViewModel
    @State private var downloadsViewModel: ModelDownloadsViewModel
    @State private var skillStore: DemoPromptSkillStore
    @State private var selectedTab = 0

    private let configuration: DemoRuntimeConfiguration

    init(configuration: DemoRuntimeConfiguration = DemoConfiguration.make()) {
        self.configuration = configuration
        self._viewModel = State(initialValue: DemoViewModel(configuration: configuration))
        self._skillStore = State(initialValue: DemoPromptSkillStore())
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
                downloadsViewModel: downloadsViewModel,
                skillStore: skillStore,
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

            SkillsTab(store: skillStore)
                .tabItem {
                    Label("Skills", systemImage: "sparkles")
                }
                .tag(2)

            SettingsTab(
                viewModel: viewModel,
                downloadsViewModel: downloadsViewModel,
                skillStore: skillStore
            )
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)
        }
        .tint(.blue)
        .task {
            await refreshAll()
        }
    }

    private func refreshAll() async {
        await viewModel.refresh()
        await downloadsViewModel.updateDescriptors(viewModel.downloadableModels)
        await downloadsViewModel.refresh()
    }
}

#Preview {
    ContentView(configuration: DemoConfiguration.preview())
}
