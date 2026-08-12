import SwiftUI

struct SettingsView: View {
    @AppStorage("marketDataSource") private var marketDataSourceRaw: String = MarketDataSource.coinbase.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(MarketDataSource.allCases) { source in
                        Button {
                            marketDataSourceRaw = source.rawValue
                        } label: {
                            HStack {
                                Text(source.displayName)
                                Spacer()
                                if source.rawValue == marketDataSourceRaw {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                } header: {
                    Text("Market Data Source")
                } footer: {
                    Text("Prices are for informational purposes only and may be delayed. If the selected source is unavailable, the app automatically falls back to another exchange.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
