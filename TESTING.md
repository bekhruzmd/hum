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
