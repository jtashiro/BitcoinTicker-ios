import Foundation

/// Mirrors the Android app's list of supported exchanges (BitcoinPriceWrapper.java).
enum MarketDataSource: String, CaseIterable, Identifiable, Codable {
    case binance, bitfinex, bitstamp, coinbase, coingecko, cryptocompare, gemini, kraken

    var id: String { rawValue }
    var displayName: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

enum PriceServiceError: Error {
    case decodingFailed
}

enum PriceService {

    /// Fetch the BTC/USD price from a single named exchange.
    static func fetchPrice(from source: MarketDataSource) async throws -> Double {
        switch source {
        case .binance: return try await fetchBinance()
        case .bitfinex: return try await fetchBitfinex()
        case .bitstamp: return try await fetchBitstamp()
        case .coinbase: return try await fetchCoinbase()
        case .coingecko: return try await fetchCoingecko()
        case .cryptocompare: return try await fetchCryptocompare()
        case .gemini: return try await fetchGemini()
        case .kraken: return try await fetchKraken()
        }
    }

    /// Tries the preferred source first, then falls back through the rest in order —
    /// same behavior as fetchMarketData() in the Android MainActivity.
    static func fetchPriceWithFallback(preferred: MarketDataSource) async -> (price: Double, source: MarketDataSource)? {
        let ordered = [preferred] + MarketDataSource.allCases.filter { $0 != preferred }
        for source in ordered {
            if let price = try? await fetchPrice(from: source) {
                return (price, source)
            }
        }
        return nil
    }

    // MARK: - Individual exchange calls

    private static func fetchBinance() async throws -> Double {
        struct Response: Decodable { let price: String }
        let url = URL(string: "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let value = Double(decoded.price) else { throw PriceServiceError.decodingFailed }
        return value
    }

    private static func fetchBitfinex() async throws -> Double {
        let url = URL(string: "https://api-pub.bitfinex.com/v2/tickers?symbols=tBTCUSD")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let array = try JSONSerialization.jsonObject(with: data) as? [[Any]],
              let first = array.first, first.count > 7,
              let value = first[7] as? Double else {
            throw PriceServiceError.decodingFailed
        }
        return value
    }

    private static func fetchBitstamp() async throws -> Double {
        struct Response: Decodable { let last: String }
        let url = URL(string: "https://www.bitstamp.net/api/v2/ticker/btcusd")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let value = Double(decoded.last) else { throw PriceServiceError.decodingFailed }
        return value
    }

    private static func fetchCoinbase() async throws -> Double {
        struct Response: Decodable {
            struct Payload: Decodable { let amount: String }
            let data: Payload
        }
        let url = URL(string: "https://api.coinbase.com/v2/prices/spot?currency=USD")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let value = Double(decoded.data.amount) else { throw PriceServiceError.decodingFailed }
        return value
    }

    private static func fetchCoingecko() async throws -> Double {
        struct Response: Decodable {
            struct Bitcoin: Decodable { let usd: Double }
            let bitcoin: Bitcoin
        }
        let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Response.self, from: data).bitcoin.usd
    }

    private static func fetchCryptocompare() async throws -> Double {
        struct Response: Decodable { let USD: Double }
        let url = URL(string: "https://min-api.cryptocompare.com/data/price?fsym=BTC&tsyms=USD")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Response.self, from: data).USD
    }

    private static func fetchGemini() async throws -> Double {
        struct Response: Decodable { let last: String }
        let url = URL(string: "https://api.gemini.com/v1/pubticker/btcusd")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let value = Double(decoded.last) else { throw PriceServiceError.decodingFailed }
        return value
    }

    private static func fetchKraken() async throws -> Double {
        struct Response: Decodable {
            struct Result: Decodable { let c: [String] }
            let result: [String: Result]
        }
        let url = URL(string: "https://api.kraken.com/0/public/Ticker?pair=XXBTZUSD")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let first = decoded.result.values.first,
              let priceString = first.c.first,
              let value = Double(priceString) else {
            throw PriceServiceError.decodingFailed
        }
        return value
    }
}
