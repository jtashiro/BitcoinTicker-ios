import SwiftUI

struct ConverterView: View {
    @AppStorage("marketDataSource") private var marketDataSourceRaw: String = MarketDataSource.coinbase.rawValue
    @State private var price: Double? = nil
    @State private var btcText: String = ""
    @State private var usdText: String = ""
    @FocusState private var focusedField: Field?

    private enum Field { case btc, usd }

    private var marketDataSource: MarketDataSource {
        MarketDataSource(rawValue: marketDataSourceRaw) ?? .coinbase
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                rateHeader
                    .padding(.top, 24)

                Spacer()

                VStack(spacing: 32) {
                    amountField(
                        label: "BITCOIN",
                        symbol: "₿",
                        symbolColor: .orange,
                        text: $btcText,
                        placeholder: "0.00000000",
                        field: .btc
                    )

                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.orange.opacity(0.5))

                    amountField(
                        label: "US DOLLAR",
                        symbol: "$",
                        symbolColor: .green,
                        text: $usdText,
                        placeholder: "0.00",
                        field: .usd
                    )
                }
                .padding(.horizontal, 36)

                Spacer()
                Spacer()
            }
        }
        .navigationTitle("Convert")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .foregroundColor(.orange)
                }
            }
        }
        .task { await fetchPrice() }
        .onAppear { Task { await fetchPrice() } }
    }

    @ViewBuilder
    private var rateHeader: some View {
        VStack(spacing: 4) {
            if let p = price {
                Text("1 BTC = \(currencyString(p))")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(.orange)
                Text(marketDataSource.displayName + " · Live rate")
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.6))
            } else {
                ProgressView().tint(.orange)
            }
        }
        .frame(height: 44)
    }

    @ViewBuilder
    private func amountField(
        label: String,
        symbol: String,
        symbolColor: Color,
        text: Binding<String>,
        placeholder: String,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.gray)
                .kerning(2)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(symbol)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(symbolColor)
                    .frame(width: 28, alignment: .leading)

                TextField(placeholder, text: text)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: field)
                    .onChange(of: text.wrappedValue) {
                        guard focusedField == field else { return }
                        convert(from: field)
                    }
            }

            Rectangle()
                .fill(Color.orange.opacity(0.2))
                .frame(height: 1)
        }
    }

    private func convert(from field: Field) {
        guard let p = price else { return }
        switch field {
        case .btc:
            let clean = btcText.replacingOccurrences(of: ",", with: "")
            if let btc = Double(clean), btc > 0 {
                usdText = formatUSD(btc * p)
            } else {
                usdText = ""
            }
        case .usd:
            let clean = usdText.replacingOccurrences(of: ",", with: "")
            if let usd = Double(clean), usd > 0 {
                btcText = formatBTC(usd / p)
            } else {
                btcText = ""
            }
        }
    }

    private func fetchPrice() async {
        if let info = await PriceService.fetchPriceInfoWithFallback(preferred: marketDataSource) {
            price = info.price
            // Re-run conversion with updated price if a field already has a value
            if focusedField == .btc || (focusedField == nil && !btcText.isEmpty) {
                convert(from: .btc)
            } else if !usdText.isEmpty {
                convert(from: .usd)
            }
        }
    }

    private func currencyString(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }

    private func formatUSD(_ value: Double) -> String {
        guard value > 0 else { return "" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func formatBTC(_ value: Double) -> String {
        guard value > 0 else { return "" }
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 8
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.8f", value)
    }
}

#Preview {
    NavigationStack { ConverterView() }
        .preferredColorScheme(.dark)
}
