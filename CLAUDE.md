# Hum

Native macOS app (SwiftUI, Swift 5.10+, macOS 14+) that displays synced lyrics for whatever is playing in Spotify or Apple Music in a small floating window.

## Project Decisions & Configuration
- **Project generation**: XcodeGen via `project.yml` (`brew install xcodegen && xcodegen`).
- **Bundle ID**: `com.yourname.hum` (update `project.yml` with your identifier).
- **Hardened Runtime**: ON (`ENABLE_HARDENED_RUNTIME = YES`).
- **App Sandbox**: OFF (`com.apple.security.app-sandbox = false`) for Apple Events automation.
- **Entitlements**: `com.apple.security.automation.apple-events`, `com.apple.security.network.client`.
- **Info.plist**: `NSAppleEventsUsageDescription` explains why Hum reads Spotify and Apple Music playback.
- **Dependencies**: None (zero third-party dependencies in MVP).

## Architecture

```
Hum/
├── App/        # HumApp entry point, Window & MenuBarExtra scenes, WindowAccessor
├── Playback/   # Track & PlaybackState models, AppleScriptReader, NowPlayingStore
├── Lyrics/     # LRCParser, LRCLibClient, LyricsStore (in-memory cache + cancellation)
└── Views/      # FloatingLyricsView, HeaderView, LyricsListView, state views
HumTests/       # Unit tests (XCTest) for LRCParser
```

### 1. Playback (`Hum/Playback`)
- Uses `NSAppleScript` (never the private `MediaRemote` framework).
- Checks `NSWorkspace.shared.runningApplications` by bundle ID (`com.spotify.client`, `com.apple.Music`) before running scripts so inactive apps are never launched.
- If both apps are running, prefers the one currently playing; otherwise falls back to the first running app with a track.
- Parses fields joined by a rare separator (`\u{001F}` / unit separator) and normalizes `,` decimal separators to `.` for locale resilience.
- `NowPlayingStore` (`@Observable @MainActor`) polls every 1s on a background task/timer and interpolates playback position (`position + Date().timeIntervalSince(fetchedAt)`) while playing for smooth lyric highlighting.
- Handles AppleScript error `-1743` (not authorized) and surfaces a clear permission prompt directing the user to **System Settings > Privacy & Security > Automation**.

### 2. Lyrics (`Hum/Lyrics`)
- Fetches from **LRCLIB** (`https://lrclib.net/api/get` with rounded integer duration, falling back on 404 to `/api/search` and picking the first result within ±2s).
- Sends `User-Agent: Hum/0.1 (https://github.com/<me>/hum)`.
- Prefers `syncedLyrics`, falls back to `plainLyrics`, and handles `instrumental == true` ("Instrumental").
- `LRCParser` supports multiple timestamps per line (`[00:12.34][01:05.00]text`), `[mm:ss]`, `[mm:ss.xx]`, and `[mm:ss.xxx]`, ignores metadata tags (`[ar:]`, `[ti:]`, etc.), and sorts lines by timestamp.
- Fetches only on track change, caches in memory by `title+artist+duration`, and cancels in-flight tasks when the track changes again.

### 3. Views (`Hum/Views`) & App (`Hum/App`)
- Single floating `Window` scene with hidden title bar, `.floating` window level via `NSViewRepresentable`, background dragging (`isMovableByWindowBackground = true`), and `.ultraThinMaterial` translucent background.
- `MenuBarExtra` with Show/Hide Window, Float on Top toggle, and Quit.
- `ScrollViewReader` + `TimelineView(.periodic(from: .now, by: 0.2))` for smooth active-line highlighting and auto-scrolling.

## Roadmap
- **Phase 2 — Polish**: Settings window (`@AppStorage`, font size, alignment, opacity, launch at login via `SMAppService`, player preference), smooth line transitions (1 / 3 / all lines), compact subtitle mode, click-to-seek, Apple Music artwork via AppleScript raw data.
- **Phase 3 — Listening diary + weekly recap**: Local SwiftData `Play` log (30s or 50% threshold), searchable diary view, weekly recap with Swift Charts.
- **Phase 4 — Weather + wallpapers**: Optional MET Norway weather chip (CoreLocation / manual city, `If-Modified-Since` caching) and bundled background themes.
- **Phase 5 — Ship it**: Developer ID signing + `notarytool` + DMG (`scripts/release.sh`), Sparkle updates, Lemon Squeezy licensing (7-day trial + offline cache), and `/site` landing page.
