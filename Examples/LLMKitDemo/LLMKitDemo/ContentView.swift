import LLMExampleUI
import SwiftUI

struct ContentView: View {
    private let configuration: LLMKitExampleConfiguration

    init(configuration: LLMKitExampleConfiguration = DemoConfiguration.make()) {
        self.configuration = configuration
    }

    var body: some View {
        LLMKitExampleScreen(configuration: configuration)
    }
}

#Preview {
    ContentView()
}
