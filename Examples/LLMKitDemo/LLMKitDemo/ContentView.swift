import LLMExampleUI
import SwiftUI

struct ContentView: View {
    private let configuration = DemoConfiguration.make()

    var body: some View {
        LLMKitExampleScreen(configuration: configuration)
    }
}

#Preview {
    ContentView()
}
