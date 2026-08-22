import Foundation

enum MarketDataSource: String, CaseIterable, Identifiable, Codable {
    case bitfinex, bitstamp, coinbase, coingecko, gemini, kraken

    var id: String { rawValue }
    var displayName: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

struct PriceInfo {
    let price: Double
    let change24h: Double?   // percentage, e.g. 2.5 means +2.5%
    let high24h: Double?
    let low24h: Double?
    let source: MarketDataSource
}

enum PriceServiceError: Error {
    case decodingFailed
}

enum PriceService {

    static func fetchPriceInfo(from source: MarketDataSource) async throws -> PriceInfo {
        switch source {
        case .bitfinex:  return try await fetchBitfinex()
        case .bitstamp:  return try await fetchBitstamp()
        case .coinbase:  return try await fetchCoinbase()
        case .coingecko: return try await fetchCoingecko()
        case .gemini:    return try await fetchGemini()
        case .kraken:    return try await fetchKraken()
        }
    }

    static func fetchPriceInfoWithFallback(preferred: MarketDataSource) async -> PriceInfo? {
        let ordered = [preferred] + MarketDataSource.allCases.filter { $0 != preferred }
        for source in ordered {
            if let info = try? await fetchPriceInfo(from: source) {
                return info
            }
        }
        return nil
    }

    /// Returns 24h change %, high, and low from CoinGecko — used to fill gaps when the
    /// selected exchange doesn't provide these fields (e.g. Coinbase, Gemini).
    static func fetchMarketStats() async -> (change24h: Double, high24h: Double, low24h: Double)? {
        struct Coin: Decodable {
            let price_change_percentage_24h: Double?
            let high_24h: Double?
            let low_24h: Double?
        }
        let url = URL(string: "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&ids=bitcoin")!
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let coins = try? JSONDecoder().decode([Coin].self, from: data),
              let coin = coins.first,
              let change = coin.price_change_percentage_24h,
              let high = coin.high_24h,
              let low = coin.low_24h else { return nil }
        return (change, high, low)
    }

    /// Returns the current Bitcoin block height from mempool.space.
    static func fetchBlockHeight() async -> Int? {
        let url = URL(string: "https://mempool.space/api/blocks/tip/height")!
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let height = Int(text) else { return nil }
        return height
    }

    /// Returns hourly closing prices for the last 24 hours, sourced from CoinGecko.
    static func fetchSparklineData() async -> [Double] {
        struct Response: Decodable { let prices: [[Double]] }
        let url = URL(string: "https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=1")!
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let decoded = try? JSONDecoder().decode(Response.self, from: data) else { return [] }
        return decoded.prices.map { $0[1] }
    }

    // MARK: - Individual exchange calls

    private static func fetchBitfinex() async throws -> PriceInfo {
        // Response: [[SYMBOL, BID, BID_SIZE, ASK, ASK_SIZE, DAILY_CHANGE, DAILY_CHANGE_RELATIVE, LAST, VOLUME, HIGH, LOW]]
        let url = URL(string: "https://api-pub.bitfinex.com/v2/tickers?symbols=tBTCUSD")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let array = try JSONSerialization.jsonObject(with: data) as? [[Any]],
              let first = array.first, first.count > 10,
              let price = first[7] as? Double else {
            throw PriceServiceError.decodingFailed
        }
        let changePct = (first[6] as? Double).map { $0 * 100 }
        let high = first[9] as? Double
        let low = first[10] as? Double
        return PriceInfo(price: price, change24h: changePct, high24h: high, low24h: low, source: .bitfinex)
    }

    private static func fetchBitstamp() async throws -> PriceInfo {
        struct Response: Decodable {
            let last: String
            let percent_change_24: String?
            let high: String?
            let low: String?
        }
        let url = URL(string: "https://www.bitstamp.net/api/v2/ticker/btcusd")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let price = Double(decoded.last) else { throw PriceServiceError.decodingFailed }
        return PriceInfo(
            price: price,
            change24h: decoded.percent_change_24.flatMap { Double($0) },
            high24h: decoded.high.flatMap { Double($0) },
            low24h: decoded.low.flatMap { Double($0) },
            source: .bitstamp
        )
    }

    private static func fetchCoinbase() async throws -> PriceInfo {
        struct Response: Decodable {
            struct Payload: Decodable { let amount: String }
            let data: Payload
        }
        let url = URL(string: "https://api.coinbase.com/v2/prices/spot?currency=USD")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let value = Double(decoded.data.amount) else { throw PriceServiceError.decodingFailed }
        return PriceInfo(price: value, change24h: nil, high24h: nil, low24h: nil, source: .coinbase)
    }

    private static func fetchCoingecko() async throws -> PriceInfo {
        struct Coin: Decodable {
            let current_price: Double
            let price_change_percentage_24h: Double?
            let high_24h: Double?
            let low_24h: Double?
        }
        let url = URL(string: "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&ids=bitcoin")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let coins = try? JSONDecoder().decode([Coin].self, from: data),
              let coin = coins.first else { throw PriceServiceError.decodingFailed }
        return PriceInfo(
            price: coin.current_price,
            change24h: coin.price_change_percentage_24h,
            high24h: coin.high_24h,
            low24h: coin.low_24h,
            source: .coingecko
        )
    }

    private static func fetchGemini() async throws -> PriceInfo {
        struct Response: Decodable { let last: String }
        let url = URL(string: "https://api.gemini.com/v1/pubticker/btcusd")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let value = Double(decoded.last) else { throw PriceServiceError.decodingFailed }
        return PriceInfo(price: value, change24h: nil, high24h: nil, low24h: nil, source: .gemini)
    }

    private static func fetchKraken() async throws -> PriceInfo {
        struct KrakenPair: Decodable {
            let c: [String]  // last trade: [price, lot volume]
            let h: [String]  // high: [today, last 24h]
            let l: [String]  // low:  [today, last 24h]
            let o: String    // today's opening price
        }
        struct Response: Decodable { let result: [String: KrakenPair] }
        let url = URL(string: "https://api.kraken.com/0/public/Ticker?pair=XXBTZUSD")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let pair = decoded.result.values.first,
              let price = Double(pair.c.first ?? "") else {
            throw PriceServiceError.decodingFailed
        }
        let high = pair.h.count > 1 ? Double(pair.h[1]) : nil
        let low  = pair.l.count > 1 ? Double(pair.l[1]) : nil
        let change = Double(pair.o).map { open in
            open > 0 ? ((price - open) / open) * 100 : 0
        }
        return PriceInfo(price: price, change24h: change, high24h: high, low24h: low, source: .kraken)
    }
}
