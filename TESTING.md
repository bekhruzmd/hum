# Manual test list

Run the app from Xcode (or `build/DD/Build/Products/Debug/Hum.app`). Hum has no Dock icon; look for
the ♪ in the menu bar.

## Phase 1: Foundation + now playing
- [ ] With Spotify playing, the lyrics window shows the title, artist and cover within ~1 s.
- [ ] First run: macOS asks to let Hum control Spotify / Music. Click **Don't Allow** → the window
      says "Automation Permission Needed" and **Open System Settings** opens Privacy › Automation.
      Allow it there → Hum picks the song up within a second.
- [ ] Same with Apple Music (cover comes from the local file, not the network).
- [ ] Both apps open, only one playing → Hum follows the playing one. Pause it and play the other → Hum switches.
- [ ] Settings › General › Music player = Spotify → Hum ignores Music, and the other way round.
- [ ] Quit Spotify while Hum runs → Spotify is **not** relaunched; Hum shows "Nothing Playing".
- [ ] Window background picks up the cover's colors; toggle Settings › Lyrics › Tint with album colors.
- [ ] Skip through 3 tracks of the same album → the cover/tint doesn't flicker.
- [ ] System Settings › Language & Region › a region using "," decimals (e.g. Germany) → positions still correct.

## Phase 2: Synced lyrics + lyrics window
- [ ] A popular song shows synced lyrics; the current line is highlighted and stays centered.
- [ ] Click any line → playback jumps there (Spotify and Music).
- [ ] A song with only plain lyrics shows scrollable plain text.
- [ ] An instrumental track shows "Instrumental".
- [ ] An obscure track shows "No Lyrics Found".
- [ ] Turn Wi‑Fi off and play a song you already played → lyrics still show (disk cache).
      Play a new song offline → "Couldn't Load Lyrics".
- [ ] Skip quickly through 5 tracks → the final track's lyrics win (no stale lyrics).
- [ ] Menu bar: Show/Hide Lyrics Window, Float on Top, Compact Subtitle Mode, Settings…, Quit all work.
- [ ] Drag the window by its background; close it with the red button and reopen from the menu bar.
- [ ] Visible lines 1 / 3 / All, alignment, font size and opacity apply live.

## Phase 3: Word-by-word + 5 effects
- [ ] Settings › Lyrics › Effect: pick each of Karaoke Fill, Big Words, Glow, Typewriter, Wave.
      The preview animates; the lyrics window switches live.
- [ ] Words light up in time with the singing (roughly; exact for songs whose LRCLIB entry has word tags).
- [ ] Pause → the effect freezes and Activity Monitor shows Hum near 0% CPU.
- [ ] System Settings › Accessibility › Display › Reduce motion ON → every effect becomes a plain bright line.
- [ ] Lyrics late? With the lyrics window focused press ⌘] a few times → header shows "+0.3s" and lyrics move
      earlier. ⌘[ goes the other way, ⌘0 resets. Menu bar › Lyrics Offset does the same.
- [ ] Skip to another song and back → the offset is remembered per song.
- [ ] Click a line with an offset set → playback lands where that line is sung.
- [ ] Compact mode shows the current line with the karaoke fill.
- [ ] Watch Activity Monitor while lyrics animate: Hum should stay under ~5% CPU.

## Phase 4: Notch island
- [ ] Play a song. On a notched MacBook a black island wraps the notch: small cover on the left,
      dancing bars on the right. Pause → bars go flat and still.
- [ ] On an external display / Mac without a notch: a pill appears centered just under the menu bar.
- [ ] Hover the island → it springs open: cover, title, artist, prev/play/next, current lyric line
      (in your chosen effect) and a scrubber. Move away → it collapses.
- [ ] Prev / play-pause / next work. Drag or click the scrubber → playback jumps there.
- [ ] Click the cover → the lyrics window opens.
- [ ] With the island open, two-finger swipe left → next track; right → previous.
- [ ] Switch Spaces → the island stays put on every Space.
- [ ] Make an app full screen → the island hides. Settings › Island › "Show over full-screen apps" ON → it shows.
- [ ] Stop playback / quit the player → the island disappears; the notch looks normal.
- [ ] Plug in / unplug a display, or change resolution → the island moves to the right spot.
- [ ] Menu bar › Show Island toggles it.

## Phase 5: Live desktop
- [ ] Menu bar › Desktop › Turntable. A turntable appears in the middle of each display, above the
      wallpaper and **below** desktop icons. Clicks pass through to the desktop.
- [ ] Play → the tonearm swings onto the record over ~1.4 s and the record spins (33⅓ rpm; the strobe
      dots on the rim make it visible). Pause → the record stops and the arm swings back to its rest.
- [ ] Over a song, the arm creeps inward. The label shows the album cover.
- [ ] Desktop › Lyrics: big lyrics in your effect near the bottom of the screen with the next line below.
      Settings › Desktop › Background "Blurred album colors" → blurred cover fills the screen.
- [ ] Switch Spaces → it's on every Space. Mission Control doesn't show it as a window.
- [ ] Cover the desktop with a maximized window, lock the screen (⌃⌘Q), or turn on Low Power Mode →
      Activity Monitor shows Hum's CPU drop (rendering pauses).
- [ ] Connect/disconnect a display → each display gets its own window at the right size.
- [ ] Desktop › Off removes everything.

## Phase 6: Idle screen + sounds + hotkeys
- [ ] Global shortcuts work from any app: ⌃⌥Space play/pause, ⌃⌥→ next, ⌃⌥← previous, ⌃⌥L lyrics
      window, ⌃⌥D live desktop on/off, ⌃⌥I idle screen, ⌃⌥] / ⌃⌥[ lyrics offset.
- [ ] Settings › Shortcuts: click one, press a new combo → it works immediately. A combo without
      ⌘/⌃/⌥ beeps. ⎋ cancels, ⌫ clears. Assigning a combo used elsewhere moves it. Restore Defaults works.
- [ ] Menu bar › Start Idle Screen (or ⌃⌥I): fades in on every display with blurred cover, the cover,
      title, lyric in your effect, and a clock bottom-left. Move the mouse / press a key / click → it goes away.
- [ ] Settings › Idle & Sounds › Show after 2 minutes. Play music, don't touch the Mac for 2+ minutes →
      the idle screen appears. With music paused it does not.
- [ ] Set your macOS screensaver to start soon after → the screensaver covers Hum's idle screen.
      Lock the screen (⌃⌘Q) → the real lock screen is on top. Hum never asks for a password.
- [ ] Idle & Sounds › Needle drop ON → a soft thump when playback starts. Crackle ON → faint vinyl
      crackle only while playing; pause → silence. Volume slider works.
- [ ] With sounds off, Activity Monitor shows no audio CPU use from Hum.

## Polish pass: smoother, deeper, livelier
- [ ] Karaoke fill and the island scrubber move steadily, with no tiny jumps every second.
- [ ] Lyrics window: lines fade and shrink the further they are from the current line; already-sung
      lines are a bit dimmer. Hover a line to bring it forward. Scrolling springs; edges fade softly.
- [ ] During an intro or a long instrumental break, three dots fill one by one toward the next line,
      then fade away as singing resumes.
- [ ] While playing, soft album-colored light slowly drifts behind the lyrics. Pause → it rests.
- [ ] Skip a track → cover, title and artist crossfade; the island peeks open for ~3 s showing the new
      song, then tucks back in (Settings › Island › Peek open when the song changes).
- [ ] On a Force Touch trackpad, hovering the island gives a light tap.
- [ ] Activity Monitor while playing with the lyrics window open: Hum stays under ~5% CPU.

## Polish pass 2: controls, weight, menu bar lyrics
- [ ] Move the pointer over the lyrics window → a glass bar slides up with prev/play/next and a
      scrubber. Keep still ~3 s or leave → it slides away.
- [ ] Click the lyrics window, then: Space plays/pauses, ← / → jump 5 s.
- [ ] Turntable: on play the platter spins up over about a second; on pause it coasts to a stop
      over ~2 s while the arm lifts away.
- [ ] Menu bar › Lyrics in Menu Bar: the ♪ becomes the current line (long lines end in "…").
      Pause → back to ♪. Turn it off → ♪.
- [ ] The island's controls and scrubber still look right (white on black).

## Cinematic scene, Constellation lyrics, screensaver
- [ ] Settings › Lyrics › Effect › Constellation: each word lands as a star with a small label, lines
      join it to earlier words (some triangles), a turning sparkle ring marks the current word, and
      the word appears large beside it. The previous line stays faint on the left.
- [ ] Menu bar › Start Idle Screen: the Cinematic style. Black-and-white cover slowly drifting,
      smoke wisps, a thin frame with the album title breaking its top edge, date and serif clock,
      constellation lyrics, title/artist bottom-right. Any input dismisses it.
- [ ] Settings › Idle & Sounds › Style "Classic" → the earlier colorful idle screen.
- [ ] Menu bar › Desktop › Cinematic → the same scene behind your desktop icons.
- [ ] Settings › Idle & Sounds › Install Screen Saver → System Settings › Screen Saver opens; pick
      "Hum". The preview tile shows the scene. If macOS asks to let Hum access other apps' data, allow it.
- [ ] Play a song and start the screensaver (hot corner or wait). The scene shows the playing song
      with lyrics in time. Pause in your player → within ~1 s the lyrics stop moving.
- [ ] With "Require password after screen saver" on, waking still asks for your Mac password as usual.

## Screensaver feed recovery and layout

- [x] Keep Hum running; play Spotify, then start Hum from macOS Screen Saver settings. Confirm the host receives fresh song/lyrics data and paused → playing updates.
- [ ] Repeat live validation with Apple Music and multiple displays.
- [ ] Change songs, seek, pause and resume: lyrics should follow within a few seconds, and pause should stop lyric progression.
- [x] Apple’s legacyScreenSaver host loaded build 2 and read the current shared-home feed (69 synced lines), without a file-access prompt.
- [ ] Quit Hum while the saver is visible. Within 20 seconds, cached music should clear and “Open Hum to connect your music” should appear. Relaunch Hum and confirm recovery.
- [ ] Disable “Send the current song to the screensaver.” Old artwork and lyrics should clear; re-enable and confirm recovery.
- [ ] Verify an instrumental / song without synced lyrics shows a readable title and explanatory subtitle.
- [ ] Check full screen and the small Settings preview: artwork remains square and uncropped, lyrics are legible, and the clock does not overlap content.
- [ ] Enable Reduce Motion: ambient movement and lyric motion stop while song changes still update.
- [ ] After reinstalling a new saver build, end the current saver session and start a fresh one; macOS may retain an already loaded bundle until the host exits.


## Playback and motion regression pass — November 26, 2026

- [x] 56 permanent unit tests pass; one temporary full-size/thumbnail render test also passed and was removed.
- [x] Visual checks: Constellation with a long line, 320×180 preview, and disconnected state. Crowded star labels are omitted while the full line stays readable.
- [x] Playback tests cover out-of-order polls and seek invalidation/bounds. Feed tests cover shared paths, expiry, disabled sharing, cover repair and failed-install preservation.
- [ ] Enable Reduce Motion while music plays: active lines continue changing, with no word movement.
- [ ] Hide the lyrics window, close Settings and stop the saver: hidden views should stop animation work.
- [ ] Open idle preview and immediately press a key, click, scroll or move the pointer: it dismisses without an input grace period.
- [ ] Skip songs rapidly and reload lyrics during a song change: previous covers/lyrics must not reappear.

- [x] Compared cinematic layout with the supplied 18.9-second MP4: centered monochrome artwork, poster frame, serif clock, moving edge light and constellation overlay. Verified full-size and 320px renders.
- [ ] Extended thermal/battery and animation smoothness check on the final Release saver, including multiple displays. Debug saver was 26–31% of one CPU core in a short sample; background Hum was 0.8–1.0%. Do not treat Debug rendering as the Release baseline.

- [x] Both app and saver contain the `humRefraction` Metal function; tests load their actual bundled Metal libraries.
- [x] Verified Album color and Monochrome poster reference renders, including an enabled GPU effect.
- [ ] Preview live scene opens and closes cleanly; occluding the preview pauses motion.
- [ ] Switch Cinematic look during playback: app scene and system saver both adopt the choice.

- [x] Final clean Release build 3 installed; actual Apple host connected with 72 lyric lines and compiled its shaders successfully.
- [x] Short Release sample: Hum 1.4–2.0% CPU; saver 19.1–23.6% of one core, ~525 MB including graphics resources. Extended soak and further rendering optimization remain open.
- [ ] Automatic start: current macOS warning says display sleep precedes the 20-minute saver delay. Choose an earlier saver delay if automatic activation is wanted; retain the owner's lock/sleep policy.


## Clock removal and adjustable edge glow — build 4

- [x] Removed Hum's clock/date from the shared cinematic scene; the macOS clock is independent.
- [x] Feed round-trip preserves edge glow and defaults older feeds to 100%.
- [x] Rendered Off, 100% and 300%; 300% adds a broader halo and brighter continuous rim. No clock remains.
- [ ] Settings → Idle & Sounds → Edge glow persists across launch and updates the system saver while running.


### Build 4: reference music player

- The music-note menu offers **Show Mini Player** and **Show Live Scene**. The glass player uses
  real playback state, inline elapsed/remaining times, shuffle, previous, play/pause and next.
  The laptop button opens the current music app. Clicking the cover expands/collapses its artwork.
- Verify repeat expansion/reversal, hover and press feedback, drag the window by the card background,
  close/reopen, paused playback, song changes and long titles. The panel must stay bounded to its
  contents; closing/occlusion stops its timelines. Reduce Motion removes cover travel and button scaling;
  Reduce Transparency gives the card an opaque background.
- Click/drag the progress bar and release. Only one seek is sent on release, and a track change during
  a drag cancels that seek. Changing a lyric offset must not change music progress. Shuffle reflects
  the active app and is unavailable when that playback context does not support it.
- The actual macOS saver and idle screen show a read-only live music card. Input still wakes/dismisses
  them; interactive controls live in the mini player and live scene. No authentication controls exist.
- The cinematic lyric position leaves room for the card. Verify full-size and small saver previews,
  playback paused/resumed, missing lyrics/artwork, and new tracks. The classic idle clock is also removed.
- Automated checks cover shuffle parsing/propagation/clock smoothing, separate player/lyric anchors,
  old feed decoding, mini-player window sizing and close lifecycle. Temporary player/scene PNG render
  checks were inspected and removed.

- Final verification: 61 permanent tests passed; optimized Release build and strict code-signature
  verification passed. Native app checks confirmed cover expansion/collapse, real Spotify play/pause,
  seeking with lyric updates, and the live scene's clear lyric/card spacing. macOS Settings' Hum saver
  preview displayed the new card and a changed song. The Window menu has Mini Player (⇧⌘M) and Live
  Scene (⇧⌘L); Hum's application menu now provides Settings (⌘,).
- Existing AppIntents metadata/SwiftUI settings diagnostics remain. Extended performance soak and
  Apple Music playback-control validation were not repeated in this pass.

## Island animation, Beat Glow, interactive player, new Settings
- [ ] Settings opens as a sidebar window: Now Playing; Features (Island, Screen Saver, Desktop, Lyrics,
      Sound, Beat Glow, Keys); General. Features that are off show "Off". Search filters the list.
- [ ] Island page: the mini notch keeps opening and closing; switching Motion (Smooth/Snappy/Bouncy)
      and Size changes it live.
- [ ] Real island: hover → after the hover delay it springs out of the notch; content sharpens in.
      Leave → content fades quickly and the shape tucks back without bouncing.
- [ ] Open with "Click": hovering only nudges the cover/bars; a click opens it.
- [ ] Pull the closed island down with a drag or a two-finger swipe down → opens. Swipe up → closes.
      Open + swipe sideways → skips tracks.
- [ ] Size Compact / Regular / Large changes the open island; Compact hides the lyric line.
- [ ] Haptics off → no tap on a Force Touch trackpad. Peek length changes how long it stays open on song change.
- [ ] Beat Glow on → a line of light runs around every display while music plays, flaring on sung words;
      pause → fades out. Clicks pass through it.
- [ ] Beat Glow page: Album / Custom (color picker) / Spectrum; Orbit / Pulse / Steady; speed,
      thickness and brightness apply live to the preview and the real glow.
- [ ] Idle scene (menu bar › Show Idle Scene): move the mouse → the glass player slides up; pause,
      skip, scrub and shuffle work; it hides after ~3 s still. A key or a click on empty space closes.
- [ ] Hum screensaver (after Reinstall): the player shows live but can't be clicked (macOS ends the
      screensaver on any input). Glow color/style match the Beat Glow settings.

## Island polish (glass, fixed panel, pages)
- [ ] Open the island repeatedly, fast, from different angles, and while a song changes: it never
      jumps, clips or opens-closes-opens. Move away mid-opening → it reverses smoothly from where it is.
- [ ] Open: black where it meets the notch, fading into frosted glass that shows your wallpaper
      blurred behind it. Page dots on the left of the notch, expand button on the right.
- [ ] Player page: artwork, title/artist, live bars, elapsed time · scrubber · track length,
      large previous / play-pause / next, and a laptop button that brings the player app forward.
- [ ] Click the dots or swipe sideways → slides to Lyrics (current line + next line) and back,
      in the matching direction.
- [ ] Menu bar items right next to the island stay clickable when it's closed.
- [ ] System Settings › Accessibility › Display › Reduce transparency → the island becomes solid dark.

## Liquid Glass material
- [ ] Settings › Island › Material (also General › Appearance): Liquid Glass / Frosted / Solid.
- [ ] Liquid Glass: the open island, the idle scene's music player and the lyrics window's control
      bar use Apple's glass (refracts and catches light from what's behind). The island stays black
      where it meets the notch.
- [ ] Frosted looks like before; Solid is opaque dark (adapts to light mode in the lyrics window).
- [ ] Reduce Transparency on → everything is Solid, and Settings says why.
- [ ] Hum screensaver (after Reinstall): the music player uses the chosen material.
