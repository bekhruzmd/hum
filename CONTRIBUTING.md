# Contributing to Hum

Thank you for your interest in contributing to Hum! Whether you are reporting an issue, proposing an idea, or writing code, your help is welcome.

---

## 🚀 Getting Started

1. **Fork** the repository on GitHub.
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/<your-username>/hum.git
   cd hum
   ```
3. Open `Hum.xcodeproj` in Xcode (15.4 or later):
   ```bash
   open Hum.xcodeproj
   ```
4. Build and run the app with `Cmd + R`.
5. Run the unit tests with `Cmd + U` to verify your environment.

---

## 🛠️ Making Changes

* Create a new branch for your feature or fix:
  ```bash
  git checkout -b feature/my-new-feature
  ```
* Keep changes modular and focused.
* Write unit tests for new logic (e.g. in `HumTests/`).
* Ensure all tests pass before opening a pull request:
  ```bash
  xcodebuild -scheme Hum -destination 'platform=macOS' test
  ```

---

## 📬 Submitting a Pull Request

1. Push your branch to your GitHub fork:
   ```bash
   git push origin feature/my-new-feature
   ```
2. Open a Pull Request against the `main` branch of `bekhruzmd/hum`.
3. Provide a clear description of your changes, the rationale, and any testing performed.
4. Our GitHub Actions CI will automatically test and verify your PR.

---

## 🐛 Reporting Bugs

If you encounter unexpected behavior or a crash:
1. Check the [Issues tab](https://github.com/bekhruzmd/hum/issues) to see if it has already been reported.
2. If not, open a new issue using the **Bug Report** template, including your macOS version, music player (Spotify or Apple Music), and steps to reproduce.

Thank you for helping make Hum better for everyone!
