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
    @State private var sparklineMin: Double = 0
    @State private var sparklineMax: Double = 1
    @State private var blockHeight: Int?
    @State private var marketStats: MarketStats?
    @State private var fearAndGreed: FearAndGreed?
    @State private var chartDays: Int = 1
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
        .onChange(of: chartDays) { Task { await refreshSparkline() } }
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

            if let change = displayChange {
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
        VStack(spacing: compact ? 8 : (pad ? 20 : 14)) {
            // Chart timeframe picker
            Picker("Period", selection: $chartDays) {
                Text("24H").tag(1)
                Text("7D").tag(7)
                Text("30D").tag(30)
            }
            .pickerStyle(.segmented)

            // Sparkline — isolated struct so the 1s clock timer can't trigger chart layout
            if !sparklineData.isEmpty {
                SparklineChart(
                    data: sparklineData,
                    minY: sparklineMin,
                    maxY: sparklineMax,
                    color: sparklineColor,
                    height: compact ? (pad ? 90 : 56) : (pad ? 200 : 80)
                )
            }

            // 24H HIGH / 24H LOW
            if let high = displayHigh, let low = displayLow {
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

            // MKT CAP / 24H VOL — hidden on iPhone landscape to avoid crowding
            if (!compact || pad), let stats = marketStats, stats.marketCap > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MKT CAP")
                            .font(.system(size: pad ? 12 : 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                            .kerning(1)
                        Text(abbreviatedValue(stats.marketCap))
                            .font(.system(
                                size: pad ? 24 : 15,
                                weight: .semibold, design: .rounded
                            ))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("24H VOL")
                            .font(.system(size: pad ? 12 : 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                            .kerning(1)
                        Text(abbreviatedValue(stats.volume24h))
                            .font(.system(
                                size: pad ? 24 : 15,
                                weight: .semibold, design: .rounded
                            ))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            }

            // Fear & Greed — hidden on iPhone landscape
            if (!compact || pad), let fng = fearAndGreed {
                HStack {
                    Text("FEAR & GREED")
                        .font(.system(size: pad ? 12 : 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                        .kerning(1)
                    Spacer()
                    HStack(spacing: 6) {
                        Text("\(fng.value)")
                            .font(.system(
                                size: pad ? 24 : 15,
                                weight: .bold, design: .rounded
                            ))
                            .foregroundColor(fearGreedColor(fng.value))
                        Text(fng.classification)
                            .font(.system(size: pad ? 16 : 12, weight: .medium))
                            .foregroundColor(fearGreedColor(fng.value).opacity(0.8))
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

            if let height = blockHeight {
                VStack(spacing: 3) {
                    Link(destination: URL(string: "https://mempool.space/block-height/\(height)")!) {
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
                    Link(destination: URL(string: "https://mempool.space/halving")!) {
                        Text(halvingSubtitle(height))
                            .font(.system(
                                size: compact ? (pad ? 12 : 9) : (pad ? 15 : 10),
                                design: .monospaced
                            ))
                            .foregroundColor(.gray.opacity(0.45))
                    }
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

    private func abbreviatedValue(_ value: Double) -> String {
        if value >= 1_000_000_000_000 {
            return String(format: "$%.2fT", value / 1_000_000_000_000)
        } else if value >= 1_000_000_000 {
            return String(format: "$%.2fB", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        } else {
            return currencyString(value)
        }
    }

    private func fearGreedColor(_ value: Int) -> Color {
        if value < 25 { return .red }
        if value < 45 { return .orange }
        if value < 55 { return .yellow }
        return .green
    }

    private var sparklineColor: Color {
        guard let change = displayChange else { return .orange }
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

    private func halvingSubtitle(_ height: Int) -> String {
        let halvingInterval = 210_000
        let nextHalving = ((height / halvingInterval) + 1) * halvingInterval
        let remaining = nextHalving - height
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        let remainingStr = fmt.string(from: NSNumber(value: remaining)) ?? "\(remaining)"
        let secondsRemaining = Double(remaining) * 10.0 * 60.0
        let estimatedDate = Date().addingTimeInterval(secondsRemaining)
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "MMM yyyy"
        return "\(remainingStr) to halving · ~\(dateFmt.string(from: estimatedDate))"
    }

    // Downsample to at most maxPoints evenly-spaced values so the chart renders fast.
    private func applySparkline(_ raw: [Double], maxPoints: Int = 150) {
        guard !raw.isEmpty else { return }
        let sampled: [Double]
        if raw.count <= maxPoints {
            sampled = raw
        } else {
            let step = Double(raw.count - 1) / Double(maxPoints - 1)
            sampled = (0..<maxPoints).map { raw[Int(Double($0) * step)] }
        }
        var tx = Transaction(animation: nil)
        tx.disablesAnimations = true
        withTransaction(tx) {
            sparklineData = sampled
            sparklineMin = sampled.min() ?? 0
            sparklineMax = sampled.max() ?? 1
        }
    }

    private func refresh() async {
        // CoinGecko data is slow — fire and forget so fast exchange price shows immediately
        Task {
            if let stats = await PriceService.fetchMarketStats() { marketStats = stats }
        }
        Task {
            let data = await PriceService.fetchSparklineData(days: chartDays)
            applySparkline(data)
        }
        Task {
            if let fng = await PriceService.fetchFearAndGreed() { fearAndGreed = fng }
        }

        // Fast path: exchange price + block height update the UI right away
        async let priceTask = PriceService.fetchPriceInfoWithFallback(preferred: marketDataSource)
        async let blockTask = PriceService.fetchBlockHeight()
        let (newInfo, newHeight) = await (priceTask, blockTask)
        if let info = newInfo { priceInfo = info }
        if let h = newHeight { blockHeight = h }
    }

    private func refreshSparkline() async {
        let data = await PriceService.fetchSparklineData(days: chartDays)
        applySparkline(data)
    }

    // Merge exchange data with CoinGecko fallback at the display layer
    private var displayChange: Double? { priceInfo?.change24h ?? marketStats?.change24h }
    private var displayHigh: Double?   { priceInfo?.high24h   ?? marketStats?.high24h   }
    private var displayLow: Double?    { priceInfo?.low24h    ?? marketStats?.low24h    }

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

// Isolated struct so SwiftUI only re-renders the chart when its own inputs change.
// Without this, the 1-second clock timer in ContentView causes chart layout on every tick.
private struct SparklineChart: View, Equatable {
    let data: [Double]
    let minY: Double
    let maxY: Double
    let color: Color
    let height: CGFloat

    static func == (lhs: SparklineChart, rhs: SparklineChart) -> Bool {
        lhs.data == rhs.data &&
        lhs.minY == rhs.minY &&
        lhs.maxY == rhs.maxY &&
        lhs.color == rhs.color &&
        lhs.height == rhs.height
    }

    var body: some View {
        Chart(Array(data.enumerated()), id: \.offset) { index, price in
            LineMark(
                x: .value("Time", index),
                y: .value("Price", price)
            )
            .interpolationMethod(.linear)
        }
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
        .chartYScale(domain: minY...maxY)
        .foregroundStyle(color)
        .frame(height: height)
        .animation(.none, value: data)
    }
}

#Preview {
    NavigationStack { ContentView() }
}
