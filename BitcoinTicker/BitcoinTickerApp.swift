import SwiftUI

@main
struct BitcoinTickerApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    ContentView()
                }
                .tabItem {
                    Label("Price", systemImage: "chart.line.uptrend.xyaxis")
                }

                NavigationStack {
                    ConverterView()
                }
                .tabItem {
                    Label("Convert", systemImage: "arrow.left.arrow.right.circle.fill")
                }
            }
            .tint(.orange)
            .preferredColorScheme(.dark)
        }
    }
}
