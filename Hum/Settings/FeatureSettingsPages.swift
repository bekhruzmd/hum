import SwiftUI

/// The current song, its controls, and lyric timing for it.
struct NowPlayingSettingsPage: View {
    let environment: AppEnvironment

    var body: some View {
        let nowPlaying = environment.nowPlaying
        if let state = nowPlaying.playbackState {
            SettingsPageScaffold(page: .nowPlaying) {
                Section {
                    HStack(spacing: 14) {
                        ArtworkView(image: nowPlaying.artworkImage, size: 76, cornerRadius: 10)
                            .shadow(color: nowPlaying.palette.highlight.opacity(0.4), radius: 10, y: 4)
                            .onDrag { ArtworkDrag.provider(for: nowPlaying.artworkImage, title: state.track.title) }
                            .help("Drag the artwork into another app or the Finder")
                        VStack(alignment: .leading, spacing: 3) {
                            Text(state.track.title).font(.system(size: 15, weight: .semibold))
                            Text(state.track.artist).foregroundStyle(.secondary)
                            Text("\(state.track.album) · \(state.track.player.displayName)")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                        .lineLimit(1)
                        Spacer()
                        TransportControls(nowPlaying: nowPlaying, isPlaying: state.isPlaying)
                    }
                    .padding(.vertical, 6)
                    Scrubber(state: state, tint: nowPlaying.palette.highlight, animate: true) { nowPlaying.seek(to: $0) }
                }

                Section {
                    let offset = environment.offsets.offset(for: state.track)
                    LabeledContent("Lyrics offset for this song") {
                        HStack(spacing: 6) {
                            Button("Later") { environment.nudgeOffset(by: -OffsetStore.step) }
                            Text(String(format: "%+.1f s", offset)).monospacedDigit().frame(width: 52)
                            Button("Earlier") { environment.nudgeOffset(by: OffsetStore.step) }
                            Button("Reset") { environment.offsets.reset(state.track) }
                                .disabled(offset == 0)
                        }
                        .controlSize(.small)
                    }
                    Button("Show Lyrics Window") { environment.windows.showLyrics() }
                } header: {
                    Text("Lyrics")
                } footer: {
                    Text("If lyrics run early or late, nudge them here or with ⌃⌥] and ⌃⌥[. Hum remembers the offset for each song. You can also drop a .lrc file on the lyrics window.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } else {
            VStack(spacing: 0) {
                SettingsPageHeader(page: .nowPlaying)
                NothingPlayingEmptyState()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// Centered placeholder with a way forward: open whichever players are installed.
struct NothingPlayingEmptyState: View {
    private static let players: [(name: String, bundleID: String)] = [
        ("Spotify", PlayerApp.spotify.bundleIdentifier),
        ("Music", PlayerApp.appleMusic.bundleIdentifier)
    ]

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Nothing Playing")
                .font(.system(size: 17, weight: .semibold))
            Text("Play a song in Spotify or Apple Music and it appears here.")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Self.players.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleID) != nil },
                        id: \.bundleID) { player in
                    Button("Open \(player.name)") { open(player.bundleID) }
                }
            }
            .padding(.top, 6)
        }
        .padding(.bottom, 60)
    }

    private func open(_ bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}

struct DesktopSettingsPage: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        SettingsPageScaffold(page: .desktop) {
            Section {
                Picker("Live desktop", selection: $settings.desktopMode) {
                    ForEach(DesktopMode.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                if settings.desktopMode == .lyrics {
                    Picker("Background", selection: $settings.desktopLyricsBackground) {
                        ForEach(DesktopLyricsBackground.allCases) { Text($0.displayName).tag($0) }
                    }
                }
            } footer: {
                Text("Draws on every display, above your wallpaper and below your desktop icons. It never takes clicks, and pauses when covered, locked, or in Low Power Mode.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct SoundSettingsPage: View {
    let environment: AppEnvironment

    var body: some View {
        @Bindable var settings = environment.settings
        SettingsPageScaffold(page: .sound) {
            Section {
                Toggle("Needle drop when playback starts", isOn: $settings.needleDropSound)
                Toggle("Soft vinyl crackle while playing", isOn: $settings.crackleSound)
                LabeledSlider(title: "Volume", value: $settings.soundVolume, range: 0...1, step: 0.05) {
                    "\(Int($0 * 100))%"
                }
                HStack {
                    Spacer()
                    Button {
                        environment.sounds.playNeedleDrop(volume: Float(settings.soundVolume))
                    } label: {
                        Label("Play Needle Drop", systemImage: "speaker.wave.2")
                    }
                }
            } footer: {
                Text("Hum's sounds are generated on your Mac by its own code. No audio files, no internet.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
