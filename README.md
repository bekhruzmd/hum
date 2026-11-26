<div align="center">

# 🎵 Hum

### Live constellation lyrics and ambient music companion for macOS

[![CI Status](https://github.com/bekhruzmd/hum/actions/workflows/ci.yml/badge.svg)](https://github.com/bekhruzmd/hum/actions/workflows/ci.yml)
[![macOS Deployment](https://img.shields.io/badge/macOS-14.0%2B-007AFF?logo=apple&logoColor=white)](https://apple.com/macos)
[![Swift Version](https://img.shields.io/badge/Swift-5.10%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-34C759.svg)](LICENSE)

<br/>

Hum transforms your music listening experience on macOS. As tracks play in Spotify or Apple Music, synchronized lyrics appear as celestial stars forming authentic constellations and dynamic asterisms across your desktop and screensaver.

</div>

---

## 📦 Installation

### System Requirements
- macOS 14 Sonoma or macOS 15 Sequoia (or later)
- Apple Silicon (M1/M2/M3/M4) or Intel Mac
- Spotify or Apple Music desktop client

---

### Manual Installation

1. Download the latest release archive (`Hum.zip`) from the [GitHub Releases](https://github.com/bekhruzmd/hum/releases) page.
2. Unpack the archive and copy **Hum.app** to your `/Applications` directory.
3. Copy **Hum.saver** into your `~/Library/Screen Savers/` directory.

#### Gatekeeper First-Launch Note

Because Hum is an independent community build distributed outside the Mac App Store, macOS displays a developer verification prompt on initial launch. You can permit the application using either of the following steps:

* **Terminal Command:**
  ```bash
  xattr -dr com.apple.quarantine "/Applications/Hum.app"
  ```
* **System Settings:**
  Navigate to **System Settings > Privacy & Security**, scroll down to the security section, and click **Open Anyway**.

---

### Screensaver Setup

1. Place `Hum.saver` into `~/Library/Screen Savers/`.
2. Open **System Settings > Screen Saver** and choose **Hum**.
3. While Hum runs in the background, the screensaver reads playback updates directly and renders full-screen constellation lyrics with Metal refraction shaders.

---

## 💡 How It Works

- **Live Lyric Streaming**: Queries synchronized word-by-word and line-by-line lyric data across international music catalogs via community APIs.
- **Constellation Mapping**: Dynamically maps lyric words to real constellations (such as Ursa Major, Orion, and Cassiopeia) and procedural asterisms (including Aurora, Solaris, and Nebula).
- **Directional Advancement**: Word coordinates strictly advance from left to right with natural ascents and descents across the display width.
- **Ambient Metal Effects**: Renders fluid refraction shaders and edge glow sampled from album artwork palettes.

---

## 🗺️ Project Roadmap

- [x] Word-by-word synchronized lyric rendering
- [x] Multilingual lyric search supporting international catalogs
- [x] Catalog of authentic astronomical constellations with canonical asterism links
- [x] Procedural celestial asterism generator
- [x] Monotonic forward advancement mechanics
- [x] Native ScreenSaver bundle powered by Metal shaders
- [x] Dynamic display-edge glow visualizer
- [x] Native macOS Settings window (General, Lyrics, Desktop, Idle Sounds)
- [x] Continuous Integration build and test pipeline
- [ ] User-customizable constellation pattern designer
- [ ] Live desktop wallpaper rendering mode
- [ ] Offline LRC file importer

---

## 🔧 Building from Source

### Prerequisites
- macOS 14.0 or later
- Xcode 15.4 or later

### Build Instructions

1. Clone the repository:
   ```bash
   git clone https://github.com/bekhruzmd/hum.git
   cd hum
   ```

2. Open the Xcode project:
   ```bash
   open Hum.xcodeproj
   ```

3. Select the **Hum** scheme and press `Cmd + R` to compile and run. To execute the automated test suite, press `Cmd + U`.

---

## 🤝 Contributing

Contributions are welcome. Feel free to submit issues, propose features, or open pull requests. Please review [CONTRIBUTING.md](CONTRIBUTING.md) for testing guidelines and development practices.

---

## 📑 Acknowledgments

- **[LRCLIB](https://lrclib.net)**: Community-driven synchronized lyrics database.
- **[NetEase Music](https://music.163.com)**: Comprehensive synchronized lyric resources for international tracks.
- **SwiftUI & Metal**: Apple frameworks powering native interface components and shader rendering.

---

## 📜 License

This project is distributed under the terms of the [MIT License](LICENSE).
