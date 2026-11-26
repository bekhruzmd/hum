# Hum 🎵✨

> Living constellation lyrics and cinematic music visualizers for macOS.

Hum brings your music to life on your desktop and screensaver. As songs play in Spotify or Apple Music, lyrics illuminate as stars that trace authentic astronomical constellations and celestial patterns across your screen.

---

## ✨ Features

* **🌌 Constellation Lyrics**: Words light up as stars in the sky. Lines alternate between authentic astronomical constellations (*Orion, Ursa Major, Cassiopeia, Cygnus, Crux, Pegasus*) and generative cosmic asterisms (*Aurora, Solaris, Nebula, Phoenix, Pulsar*).
* **🎶 Word-by-Word Synchronized Lyrics**: Real-time synchronized lyrics with support for global music in any language (English, Russian, Spanish, Japanese, Korean, Uzbek, and more) powered by open community lyrics providers.
* **🖥️ Cinematic Screensaver**: Fluid Metal refraction shaders and dynamic display-edge glow turn your Mac into an ambient visualizer when idle.
* **⚙️ Lightweight & Native**: Built entirely in Swift and SwiftUI. Lives comfortably in your menu bar without cluttering your dock.

---

## 🚀 Getting Started

### System Requirements

* **Operating System**: macOS 14 Sonoma or macOS 15 Sequoia (or later)
* **Hardware**: Apple Silicon (M1/M2/M3/M4) or Intel Mac
* **Music Players**: Spotify or Apple Music

---

### Installing the App

1. Download the latest release from the [Releases](https://github.com/bekhruzmd/hum/releases) page.
2. Drag **Hum.app** into your `/Applications` folder.
3. Open **Hum** from Launchpad or Applications.

> **Note on First Launch:**
> Since Hum is an independent open-source project without a paid Apple Developer certificate, macOS may show a notice on first launch:
> * Simply open **System Settings > Privacy & Security**, scroll down, and click **Open Anyway**.
> * Alternatively, run this single command in Terminal:
>   ```bash
>   xattr -dr com.apple.quarantine "/Applications/Hum.app"
>   ```

---

### Installing the Screensaver

1. Copy `Hum.saver` into your `~/Library/Screen Savers/` folder.
2. Open **System Settings > Screen Saver** and select **Hum**.
3. Make sure Hum is running so it can feed current track lyrics to the screensaver.

---

## 🛠️ Building from Source

If you want to run or modify Hum yourself, building from source is simple:

### Step 1: Clone the repository

```bash
git clone https://github.com/bekhruzmd/hum.git
cd hum
```

### Step 2: Open in Xcode

```bash
open Hum.xcodeproj
```

### Step 3: Run the project

* Select the **Hum** scheme in the top toolbar.
* Press `Cmd + R` (or click the **Play** button) to build and run the app.
* To run the unit test suite, press `Cmd + U`.

---

## 📂 Project Structure

```text
├── Hum/                   # Main macOS application
│   ├── App/               # App lifecycle, environment, and settings
│   ├── Effects/           # Constellation and lyric animation renderers
│   ├── Lyrics/            # Synchronized lyrics fetchers and parsers
│   ├── Playback/          # Spotify and Apple Music state monitoring
│   └── Surfaces/          # UI surfaces: Menu bar, Settings, and Cinematic scenes
├── HumSaver/              # Native macOS ScreenSaver bundle
├── HumTests/              # Automated unit tests and test suites
└── Hum.xcodeproj/         # Xcode project configuration
```

---

## 🤝 Contributing

Contributions, bug reports, and feature suggestions are welcome! Whether you are an experienced Swift developer or just starting out, feel free to open an issue or submit a pull request. Check out [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
