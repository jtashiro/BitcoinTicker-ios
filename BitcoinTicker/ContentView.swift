import SwiftUI
import Charts
import Combine

struct ContentView: View {
    @AppStorage("marketDataSource") private var marketDataSourceRaw: String = MarketDataSource.coinbase.rawValue
    @AppStorage("btcPortfolio") private var btcPortfolioStr: String = ""
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass
    @State private var currentTime = Date()
    @State private var priceInfo: PriceInfo?
    @State private var sparklineData: [Double] = []
    @State private var blockHeight: Int?
    @State private var showSettings = false

    private var marketDataSource: MarketDataSource {
        MarketDataSource(rawValue: marketDataSourceRaw) ?? .coinbase
    }

    private var isIPad: Bool {
        hSizeClass == .regular && vSizeClass == .regular
    }

    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let priceTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    if geo.size.width > geo.size.height {
                        landscapeLayout(geo: geo)
                    } else {
                        portraitLayout(geo: geo)
                    }
                }
                .scrollBounceBehavior(.always)
                .refreshable { await refresh() }
            }
        }
        .onReceive(clockTimer) { time in currentTime = time }
        .onReceive(priceTimer) { _ in Task { await refresh() } }
        .task { await refresh() }
        .onChange(of: marketDataSourceRaw) { Task { await refresh() } }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    // MARK: - Portrait

    @ViewBuilder
    private func portraitLayout(geo: GeometryProxy) -> some View {
        let pad = isIPad
        VStack(spacing: 0) {
            Spacer()

            priceSection(compact: false, pad: pad)
                .padding(.bottom, pad ? 40 : 20)

            sectionDivider

            marketSection(compact: false, pad: pad)
                .padding(.vertical, pad ? 36 : 18)

            sectionDivider

            infoSection(compact: false, pad: pad)
                .padding(.top, pad ? 36 : 18)

            Spacer()
        }
        .padding(.horizontal, pad ? 72 : 28)
        .frame(minHeight: geo.size.height)
    }

    // MARK: - Landscape

    @ViewBuilder
    private func landscapeLayout(geo: GeometryProxy) -> some View {
        let pad = isIPad
        HStack(alignment: .center, spacing: pad ? 48 : 28) {
            VStack(spacing: pad ? 20 : 14) {
                priceSection(compact: true, pad: pad)
                sectionDivider
                marketSection(compact: true, pad: pad)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 1)
                .padding(.vertical, 12)

            infoSection(compact: true, pad: pad)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, pad ? 48 : 24)
        .padding(.vertical, pad ? 20 : 12)
        .frame(minHeight: geo.size.height)
    }

    // MARK: - Sections

    @ViewBuilder
    private func priceSection(compact: Bool, pad: Bool) -> some View {
        VStack(spacing: compact ? 6 : (pad ? 16 : 10)) {
            Text("BTC / USD")
                .font(.system(size: pad ? 14 : 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.gray)
                .kerning(2)

            if let price = priceInfo?.price {
                Text(currencyString(price))
                    .font(.system(
                        size: compact ? (pad ? 64 : 50) : (pad ? 96 : 66),
                        weight: .bold, design: .rounded
                    ))
                    .foregroundColor(.orange)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else {
                ProgressView()
                    .tint(.orange)
                    .scaleEffect(pad ? 2.0 : 1.4)
                    .padding(.vertical, 12)
            }

            if let change = priceInfo?.change24h {
                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                    Text(String(format: "%.2f%%", abs(change)))
                    Text("24h")
                        .foregroundColor(.gray)
                }
                .font(.system(
                    size: compact ? (pad ? 18 : 15) : (pad ? 26 : 18),
                    weight: .semibold, design: .rounded
                ))
                .foregroundColor(change >= 0 ? .green : .red)
            }
        }
    }

    @ViewBuilder
    private func marketSection(compact: Bool, pad: Bool) -> some View {
        VStack(spacing: compact ? 8 : (pad ? 20 : 12)) {
            if !sparklineData.isEmpty {
                Chart(Array(sparklineData.enumerated()), id: \.offset) { index, price in
                    LineMark(
                        x: .value("Time", index),
                        y: .value("Price", price)
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .chartYScale(domain: (sparklineData.min() ?? 0)...(sparklineData.max() ?? 1))
                .foregroundStyle(sparklineColor)
                .frame(height: compact ? (pad ? 90 : 56) : (pad ? 200 : 80))
            }

            if let high = priceInfo?.high24h, let low = priceInfo?.low24h {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("24H HIGH")
                            .font(.system(size: pad ? 12 : 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                            .kerning(1)
                        Text(currencyString(high))
                            .font(.system(
                                size: compact ? (pad ? 17 : 13) : (pad ? 24 : 15),
                                weight: .semibold, design: .rounded
                            ))
                            .foregroundColor(.green.opacity(0.8))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("24H LOW")
                            .font(.system(size: pad ? 12 : 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                            .kerning(1)
                        Text(currencyString(low))
                            .font(.system(
                                size: compact ? (pad ? 17 : 13) : (pad ? 24 : 15),
                                weight: .semibold, design: .rounded
                            ))
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func infoSection(compact: Bool, pad: Bool) -> some View {
        VStack(spacing: compact ? 10 : (pad ? 22 : 14)) {
            if let price = priceInfo?.price,
               let holdings = Double(btcPortfolioStr), holdings > 0 {
                VStack(spacing: pad ? 6 : 3) {
                    Text("\(btcHoldingsString(holdings)) BTC")
                        .font(.system(size: pad ? 15 : 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                        .kerning(1)
                    Text(currencyString(holdings * price))
                        .font(.system(
                            size: compact ? (pad ? 30 : 20) : (pad ? 48 : 26),
                            weight: .bold, design: .rounded
                        ))
                        .foregroundColor(.white)
                    Text("portfolio value")
                        .font(.system(size: pad ? 14 : 10))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }

            if let height = blockHeight,
               let url = URL(string: "https://mempool.space/block-height/\(height)") {
                Link(destination: url) {
                    HStack(spacing: 5) {
                        Image(systemName: "cube.fill")
                            .font(.system(size: pad ? 16 : 11))
                        Text(blockHeightString(height))
                            .font(.system(
                                size: compact ? (pad ? 16 : 12) : (pad ? 20 : 13),
                                weight: .medium, design: .monospaced
                            ))
                    }
                    .foregroundColor(.orange.opacity(0.65))
                }
            }

            if let source = priceInfo?.source {
                Text(source.displayName)
                    .font(.system(size: compact ? (pad ? 16 : 12) : (pad ? 20 : 13)))
                    .foregroundColor(.gray.opacity(0.7))
            }

            VStack(spacing: pad ? 4 : 2) {
                Text(timeString)
                    .font(.system(
                        size: compact ? (pad ? 40 : 26) : (pad ? 60 : 34),
                        weight: .semibold, design: .rounded
                    ))
                    .foregroundColor(.white)
                Text(dateString)
                    .font(.system(
                        size: compact ? (pad ? 18 : 13) : (pad ? 24 : 15),
                        weight: .medium
                    ))
                    .foregroundColor(.gray)
            }
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.orange.opacity(0.15))
            .frame(height: 1)
    }

    // MARK: - Helpers

    private func currencyString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }

    private var sparklineColor: Color {
        guard let change = priceInfo?.change24h else { return .orange }
        return change >= 0 ? .green : .red
    }

    private func btcHoldingsString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func blockHeightString(_ height: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: height)) ?? "\(height)") + " blocks"
    }

    private func refresh() async {
        async let priceTask = PriceService.fetchPriceInfoWithFallback(preferred: marketDataSource)
        async let sparkTask = PriceService.fetchSparklineData()
        async let blockTask = PriceService.fetchBlockHeight()
        async let statsTask = PriceService.fetchMarketStats()
        let (newInfo, newSparkline, newHeight, stats) = await (priceTask, sparkTask, blockTask, statsTask)
        if let info = newInfo {
            priceInfo = PriceInfo(
                price: info.price,
                change24h: info.change24h ?? stats?.change24h,
                high24h: info.high24h ?? stats?.high24h,
                low24h: info.low24h ?? stats?.low24h,
                source: info.source
            )
        }
        if !newSparkline.isEmpty { sparklineData = newSparkline }
        if let h = newHeight { blockHeight = h }
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
}

#Preview {
    NavigationStack { ContentView() }
}
