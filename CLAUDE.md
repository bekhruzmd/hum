# Hum

Native macOS music companion (SwiftUI + AppKit, Swift 5.10 language mode, macOS 14+, Apple silicon and Intel).
For whatever plays in Spotify or Apple Music it shows live synced lyrics, a notch island, a live desktop,
an idle screen, Mac audio/brightness controls and a private listening diary. Everything runs on-device:
no accounts, no analytics, no tracking.

## Resume here
- Phases 1–6 done, plus two polish passes, the Constellation effect, the cinematic scene and the
  Hum screensaver (HumSaver target). The user waived the original prompt's design-identity rules
  ("act as you please and as I want"); keep: no password fields anywhere, idle screen dismisses on input.
- Screensaver: HumSaver shares Effects/, Cinematic scene, WordTimingEstimator, LyricsModels,
  AlbumPalette, SettingsTypes (listed in project.yml). Feed = JSON + cover written by
  ScreensaverFeedWriter into ~/Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver*/
  Data/Library/Application Support/Hum (only if that container exists) and ~/Library/Application Support/Hum.
- Next candidate: **Phase 7: Universal now playing (experimental)**.
  Plan: write our own small Perl bridge (macOS 15.4+ only answers Apple-signed processes, and
  /usr/bin/perl is Apple-signed) that loads MediaRemote and prints now-playing JSON lines;
  `UniversalSource: PlaybackSource` reads it. Off by default; fall back to AppleScript sources on any failure.
- Visual check trick: a throwaway XCTest that renders a view with `ImageRenderer` to a PNG in the
  scratchpad (never commit it). `NowPlayingStore.setPreviewState` (DEBUG) injects fake playback.
- Build: `xcodegen && xcodebuild -scheme Hum -destination 'platform=macOS' -derivedDataPath build/DD build`
- Test: same with `test`. Gate per phase: zero warnings, tests pass, TESTING.md updated, commit `Phase N: <name>`.
- Never commit CLAUDE.md or `.claude/` (user's global rule). Commit as the user's git identity, no AI attribution.

## Phase checklist
- [x] Phase 1: Foundation + now playing
- [x] Phase 2: Synced lyrics + lyrics window
- [x] Phase 3: Word-by-word + 5 effects
- [x] Phase 4: Notch island
- [x] Phase 5: Live desktop
- [x] Phase 6: Idle screen + sounds + hotkeys
- [ ] Phase 7: Universal now playing (experimental)
- [ ] Phase 8: Mac controls
- [ ] Phase 9: Listening diary + recap
- [ ] Phase 10: Extras
- [ ] Phase 11: Quality pass
- [ ] Phase 12: Ship (needs the user's Apple Team ID first)

## Architecture

```
Hum/
  App/        HumApp (@main, MenuBarExtra only), AppDelegate, AppEnvironment (owns stores),
              SettingsStore (@Observable over UserDefaults), SettingsTypes, WindowManager (all AppKit
              windows), ObservationLoop (observeContinuously helper for AppKit-side observers)
  Playback/   PlaybackSource protocol, ScriptedSource (shared AppleScript verbs), SpotifySource,
              MusicSource, AppleScriptRunner (serial queue), PlaybackParser, NowPlayingStore,
              Track, PlaybackState, PlayerApp, ArtworkLoader (actor), ColorExtractor, AlbumPalette
  Lyrics/     LRCLibClient, LRCParser, LyricsModels, LyricsStore, LyricsCache
  Lyrics/     + WordTimingEstimator (TimedLine/TimedWord), OffsetStore, LyricsService
  Effects/    LyricEffect protocol + LyricEffectView/LiveLyricEffect, FlowLayout, KaraokeFill, BigWords,
              Glow, Typewriter, Wave, Fade (Reduce Motion)
  Surfaces/   LyricsWindow/, MenuBar/, Island/ (IslandController, IslandPanel, IslandGeometry, IslandView,
              IslandShape, PlaybackBars, Scrubber), Desktop/ (DesktopController, DesktopView, TurntableView,
              BlurredArtwork), IdleScreen/ (IdleScreenController, IdleScreenView)
  Controls/   Hotkeys/ (KeyCombo, HotkeyStore, HotkeyManager), Sounds/ (SoundSynth, SoundEngine)
  App/        + RenderGate (lock/sleep/screensaver/Low Power signals)
  Diary/      (Phase 9)
  Settings/   SettingsView (TabView), one *SettingsTab per feature
HumTests/     parser, playback parsing, color extraction, cache tests
```

Data flow: `NowPlayingStore` polls (the only poll timer, 1 s) → picks the playing source, else the first
paused one → on track identity change calls `onTrackChange` (wired in `AppEnvironment` to
`LyricsStore.update`) and loads artwork + palette through `ArtworkLoader`. Views read the stores
directly; AppKit managers use `observeContinuously`.

## Decisions log
- **App Sandbox OFF**: sending Apple Events to arbitrary apps and (later) Core Audio taps, CGWindow
  levels and DDC need it off. Hardened Runtime ON. Entitlements: `automation.apple-events`,
  `network.client`.
- **Agent app (`LSUIElement = YES`)**: Hum lives in the menu bar and its own surfaces; no Dock icon.
  Reopening the app (Finder/Spotlight) shows the lyrics window.
- **Windows are AppKit-owned** (`WindowManager`), not SwiftUI `Window` scenes, so the later island,
  desktop and idle surfaces can share one manager and set levels/collection behavior directly.
  The Settings window is also AppKit-hosted because `showSettingsWindow:` is blocked on macOS 14+.
- **`PlaybackSource.current()` throws** instead of returning only `PlaybackState?`, so -1743
  (not authorized) can be surfaced. Sources also expose playPause/next/previous/seek/artworkData.
- **AppleScript runs on one serial background queue** (`AppleScriptRunner`), compiled scripts cached.
  Every script is wrapped in `if application id "…" is running` so a player is never relaunched.
- **Spotify duration** is ms → seconds. Numbers accept "," decimals. Fields joined by ASCII 31.
- **Artwork + palette cache**: keyed by `artist|album`, memory LRU (24) + disk in
  `~/Library/Caches/<bundle id>/Artwork/<sha256>.{img,json}`. Only `https` artwork URLs are fetched.
- **ColorExtractor**: 32 px thumbnail, k-means (k=3) with deterministic farthest-point seeding.
- **SettingsStore** keeps the old `@AppStorage` keys so existing preferences carry over.
- **Lyrics cache**: memory + disk JSON in `~/Library/Application Support/<bundle id>/Lyrics/`,
  keyed by `title|artist|duration`. "Not found" is cached for 1 day only, so new LRCLIB uploads appear.

- **Effects** are pure functions of `LyricRenderContext`; one coarse 10 Hz timeline picks the active
  line (Equatable list body), only the active line runs a 60 fps TimelineView, paused when not playing.
- **Offset sign**: positive = lyrics earlier (lyric time = position + offset), rounded to 0.1 s, per cacheKey.
- **Island**: panel frame is resized (collapsed ↔ expanded) instead of a big transparent panel, so it
  never eats menu bar clicks. Level `.statusBar`. Swipe via local scroll-wheel monitor.
- **Desktop** windows at `desktopWindow + 1` (above wallpaper, below icons), occlusion pauses them.
  Record angle derives from playback position (stops exactly with the music). Default mode Off.
- **Idle screen** at `.popUpMenu` level, below the screensaver (1000) and lock screen. Only auto-shows
  while playing. Default Off. Global key events would need Accessibility, so dismissal relies on
  local key events (Hum is activated) plus global mouse events.
- **Hotkeys** default ⌃⌥ + key; Carbon (no Accessibility permission). Paused while recording.
- **Sounds** synthesized in code (no assets); engine paused whenever no sound plays. Checked with an
  audio classifier: needle reads as a soft thump, crackle as warm crackle (~2.2 kHz brightness).
- Unit tests: the host app skips startup when `XCTestConfigurationFilePath` is set.

## Private-API register
| API | Why | What breaks if Apple changes it | Fallback |
|---|---|---|---|
| _(none yet)_ | | | |

## Network allowlist
lrclib.net (lyrics), Spotify artwork CDN URLs reported by Spotify, api.met.no (Phase 10, opt-in),
update feed (Phase 12). Nothing about the user is sent anywhere else.

## Performance notes
- One poll timer (`NowPlayingStore.start`). TimelineViews pause when playback is paused.
- Budget: <1% CPU idle, <5% while lyrics animate, no memory growth over 1 h. Numbers recorded in Phase 11.
