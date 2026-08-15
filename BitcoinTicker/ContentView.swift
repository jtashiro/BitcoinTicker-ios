import SwiftUI
import Combine

struct ContentView: View {
    @AppStorage("marketDataSource") private var marketDataSourceRaw: String = MarketDataSource.coinbase.rawValue
    @State private var currentTime = Date()
    @State private var priceText = "Loading…"
    @State private var sourceLabel = ""
    @State private var showSettings = false

    private var marketDataSource: MarketDataSource {
        MarketDataSource(rawValue: marketDataSourceRaw) ?? .coinbase
    }

    // Same cadence as the Android app: clock ticks every second, price refreshes every 60s.
    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let priceTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack {
                        Spacer()
                        VStack(spacing: 16) {
                            Text(priceText)
                                .font(.system(size: 96, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)

                            Text(sourceLabel)
                                .font(.system(size: 18))
                                .foregroundColor(.gray)

                            VStack(spacing: 4) {
                                Text(timeString)
                                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)

                                Text(dateString)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 24)
                        }
                        .padding()
                        Spacer()
                    }
                    .frame(minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.always)
                .refreshable { await fetchPrice() }
            }
        }
        .onReceive(clockTimer) { time in currentTime = time }
        .onReceive(priceTimer) { _ in Task { await fetchPrice() } }
        .task { await fetchPrice() }
        .onChange(of: marketDataSourceRaw) { Task { await fetchPrice() } }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(.white)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: currentTime)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: currentTime)
    }

    private func fetchPrice() async {
        guard let result = await PriceService.fetchPriceWithFallback(preferred: marketDataSource) else {
            priceText = "N/A"
            sourceLabel = "No data"
            return
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        priceText = formatter.string(from: NSNumber(value: result.price)) ?? "$\(Int(result.price))"
        sourceLabel = result.source.displayName
    }
}

#Preview {
    NavigationStack { ContentView() }
}
