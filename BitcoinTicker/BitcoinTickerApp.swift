import SwiftUI

@main
struct BitcoinTickerApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
            .preferredColorScheme(.dark)
        }
    }
}
