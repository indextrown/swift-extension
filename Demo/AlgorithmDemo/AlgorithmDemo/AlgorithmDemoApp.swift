import Algorithm
import SwiftUI

@main
struct AlgorithmDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

private struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text("Algorithm module loaded")
                .font(.title2)

            Text("This SwiftUI app imports the local Algorithm product.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
