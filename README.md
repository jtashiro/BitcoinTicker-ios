# BitcoinTicker — iOS (SwiftUI)

A SwiftUI port of the Android `BitcoinTicker` app: a full-screen clock that also
displays the current BTC/USD price, refreshed every 60 seconds with automatic
fallback across 8 exchanges.

## Support

Need help with Bitcoin Ticker, or have a question, bug report, or feature request?

- **Email:** [jtashiro@fiospace.com](mailto:jtashiro@fiospace.com)
- **Privacy Policy:** https://gist.github.com/jtashiro/d86a9c07dc3b7c86abbbaa79bf835a04

We typically respond within a few business days.

## What's included

| File                  | Mirrors (Android)                          |
|------------------------|---------------------------------------------|
| `PriceService.swift`   | `BitcoinPriceWrapper.java`                  |
| `ContentView.swift`    | `MainActivity.java` (layout + timers)       |
| `SettingsView.swift`   | `SettingsActivity.java`                     |
| `BitcoinTickerApp.swift` | App entry point / manifest              |

Not ported: the unused `Weather.java` / `WeatherService.java` / location code —
it wasn't wired into the current Android UI. Let me know if you actually want
weather back in.

## Setup (requires a Mac + Xcode)

1. Open Xcode → **File → New → Project → iOS → App**.
2. Product name: `BitcoinTicker`, Interface: **SwiftUI**, Language: **Swift**.
3. Delete the auto-generated `ContentView.swift` Xcode creates, and drag all
   4 files from this folder into the project (check "Copy items if needed").
4. Build & run (⌘R) on a simulator or your iPhone.

No third-party packages needed — everything uses Apple's built-in `URLSession`
and `Codable`, so there's no Retrofit/Gson/Gradle equivalent to configure.

## Before submitting to the App Store

- **Apple Developer account** ($99/year) at developer.apple.com — required to submit.
- **App icon** — 1024×1024 PNG, no transparency/rounded corners (Xcode handles the rest).
- **Category**: Utilities or Finance — Utilities is the safer/faster review path
  since this app doesn't trade or hold funds.
- **Privacy**: the app makes no user data collection beyond a locally-stored
  preference (chosen exchange). In App Store Connect's Privacy Nutrition Label,
  you can answer "Data Not Collected."
- **Disclaimer**: I added an informational-only note in Settings — Apple's
  guidelines are stricter on anything that looks like financial advice or a
  trading tool, so keeping this framed purely as a price display helps review go smoothly.
- **Screenshots**: required for each device size you support (at minimum 6.7" iPhone).
- **TestFlight**: worth doing an internal TestFlight build before public submission.

## Next steps I can help with

- Add a home screen widget (WidgetKit) or Live Activity for the lock screen — 
  a very natural iOS-native addition given this is a ticker app.
- Add a proper app icon and launch screen.
- Walk through App Store Connect setup and submission once you have a Mac/Xcode ready.
