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
