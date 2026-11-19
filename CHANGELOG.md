# Changelog

User-facing changes in each release. Pre-releases are listed on the [Releases](https://github.com/outerstudio/trayotp/releases) page.

## [0.6.0](https://github.com/outerstudio/trayotp/compare/v0.5.0...v0.6.0) (2026-11-20)

### Features

* **security:** ask for a typed master password before exports and deletes ([5ffdb2d](https://github.com/outerstudio/trayotp/commit/5ffdb2d377e66b4403087ff9a8120409f1d0feec))
* **security:** export a single token as a QR code behind the master password ([f461290](https://github.com/outerstudio/trayotp/commit/f46129002aeef855b80aa99ccb97e5fb97366003))
* **ui:** add a Deep Black theme with a pure black panel for OLED screens ([fdb9796](https://github.com/outerstudio/trayotp/commit/fdb9796a5f30b3c056d95f8b2bfefb84c7b79a3a))
* **ui:** add a Support TrayOTP menu, an About window and sponsor links in the update dialog ([5dd2d54](https://github.com/outerstudio/trayotp/commit/5dd2d5406132239e1f559f399aabadf28625f430))
* **ui:** shake the copied row, or its next code, and close 0.7 s later ([492fa08](https://github.com/outerstudio/trayotp/commit/492fa087e0579fce1ace4e901de8e8c50128ed21))

## [0.5.0](https://github.com/outerstudio/trayotp/compare/v0.4.0...v0.5.0) (2026-11-18)

A new look: the app icon is now a flat lock inside a TOTP countdown ring, and the same countdown now runs in your menu bar.

What's new

- Countdown in the menu bar. The menu bar icon counts down along with your codes, so you can see when they're about to change without opening the panel.
- New app icon. It's a dark icon with an orange lock inside a countdown ring. The ring turns at random moments. The lock screen shows the same icon.
- Flat service logos. Logos in the token list are drawn flat, without the circle behind them.
- Update channels. Choose stable, beta or alpha under updates. Pre-release versions like v1.0.0-beta.1 are now recognised.
- Release notes in the update dialog. When an update is available, you see what changed, formatted, before you install it.

Install

Download TrayOTP.zip below, unzip it and move TrayOTP to Applications. It's a universal build for Apple silicon and Intel. Builds are ad-hoc signed, not notarized, so on first launch use System Settings → Privacy & Security → Open Anyway. Existing vaults carry over.

Full changelog: https://github.com/outerstudio/trayotp/compare/v0.4.0...v0.5.0

### Features

* **icon:** dark app icon with an orange lock ([5987fb3](https://github.com/outerstudio/trayotp/commit/5987fb3a54361211691e12311d2d03f5a63090fe))
* **icon:** flat lock inside a TOTP countdown ring ([97ca67f](https://github.com/outerstudio/trayotp/commit/97ca67f2e0b0f82cfc22c7fe364f05decb1d1d10))
* **icons:** show service logos flat, without a circle ([43e8685](https://github.com/outerstudio/trayotp/commit/43e8685fb42654f8355d49547141dfcb9e4ceb54))
* **icon:** turn the icon's ring at random moments ([05f5193](https://github.com/outerstudio/trayotp/commit/05f519370db7e1ff151097079f9481ae6adb0ca7))
* **lock:** show the app icon on the lock screen ([9906f61](https://github.com/outerstudio/trayotp/commit/9906f6190e6ccb1ff84713405c7792b3d0a67788))
* **menu-bar:** count down with the codes in the menu bar icon ([e70d165](https://github.com/outerstudio/trayotp/commit/e70d165e48fd32b3c6ee24f21058c4592b6fb300))
* **updater:** choose a stable, beta or alpha update channel ([a707a4b](https://github.com/outerstudio/trayotp/commit/a707a4b8359b9c0895405b168c95b3f9963ecb2c))
* **updater:** show formatted release notes in the update dialog ([6f2fa4e](https://github.com/outerstudio/trayotp/commit/6f2fa4e279ea2fb04883632417afb6c9eea75f1a))
* **updater:** support pre-release versions like v1.0.0-beta.1 ([98d3da1](https://github.com/outerstudio/trayotp/commit/98d3da1cf83d445d6ba869eae8170f7b4d6998a6))

## [0.4.0](https://github.com/outerstudio/trayotp/compare/v0.3.0...v0.4.0) (2026-11-18)

### Features

* **export:** show Google Authenticator transfer QR codes ([1c83b10](https://github.com/outerstudio/trayotp/commit/1c83b1087476a834bd5533761a899d440a5a9033))
* **i18n:** translate the app and add a language menu ([4a9c1e7](https://github.com/outerstudio/trayotp/commit/4a9c1e7bfdb847db7e6e311ec101b69ef1323b7b))
* **icons:** edit icons in the panel before using them ([acc0b8d](https://github.com/outerstudio/trayotp/commit/acc0b8d09716be4a7c2cc0b2877f869706714225))
* **import:** read exports from Google Authenticator and 8 more apps ([31b15e6](https://github.com/outerstudio/trayotp/commit/31b15e6f2b1de8b1f03f63655c8ef9434a6f5e00))
* **panel:** color rows by their icon's main color ([d39044f](https://github.com/outerstudio/trayotp/commit/d39044f7c78ba7763c97853e5420198af2eebd25))
* **panel:** option to close the panel after copying a code ([1594694](https://github.com/outerstudio/trayotp/commit/1594694a120e9dff57a354f8238d7f5be30b09ae))
* **panel:** reorder the selected token with ⌘↑/⌘↓ ([9254bf4](https://github.com/outerstudio/trayotp/commit/9254bf44dc33c9ce05ac2298fc45841e32a37c7d))
* **panel:** show the account under the code ([a276f6d](https://github.com/outerstudio/trayotp/commit/a276f6d715153478101603c86a577aecaa08596a))
* refuse global shortcuts that apps or macOS already use ([aaeb59b](https://github.com/outerstudio/trayotp/commit/aaeb59b26ee2de7cf84e6ff71bb1a04ae1fe3291))
* scan QR codes with the camera, add or import from one screen ([3741e2c](https://github.com/outerstudio/trayotp/commit/3741e2c55fdc38c3feb4a3a23bfce4d38f990bd4))

### Bug Fixes

* lock every time also after closing the panel with Esc ([d3ac199](https://github.com/outerstudio/trayotp/commit/d3ac1999e7accee2332e70fda64307b589eb2d17))
* **panel:** keep focus and unlock state across dialogs and modes ([1ac5ba3](https://github.com/outerstudio/trayotp/commit/1ac5ba3f4412f5e1da133840fd64ce0c5abf15c9))

## [0.3.0](https://github.com/outerstudio/trayotp/compare/v0.2.0...v0.3.0) (2026-11-17)

### Features

* global shortcut to open the panel, and Esc to close it ([ee92c8e](https://github.com/outerstudio/trayotp/commit/ee92c8e07bbe1488fc3291c012b39acd6a53981a))
* hide the menu bar icon, open the panel from the launcher ([1196bee](https://github.com/outerstudio/trayotp/commit/1196bee7390acbe2ab26a7bb4fbba182eef28453))

## [0.2.0](https://github.com/outerstudio/trayotp/compare/v0.1.0...v0.2.0) (2026-11-17)

### Features

* check for updates and install them in place ([c667abf](https://github.com/outerstudio/trayotp/commit/c667abfdefb99bf7d487bca683368a07ec8b375e))
* **icon:** flatten app icon to a coral rounded square with white lock ([9d01192](https://github.com/outerstudio/trayotp/commit/9d01192d9ace4a87c846060a5fd4704b90e06a91))
* show and copy the next code on each row ([e00bb63](https://github.com/outerstudio/trayotp/commit/e00bb635856ded9ea3f56b28c6055a31119cf41e))

## [0.1.0](https://github.com/outerstudio/trayotp/compare/0a9beff169d326024f0e2c13b08de8b158700e54...v0.1.0) (2026-11-17)

### Features

* add TrayOTP macOS menu bar authenticator ([0a9beff](https://github.com/outerstudio/trayotp/commit/0a9beff169d326024f0e2c13b08de8b158700e54))
* **panel:** focus search on open and move between search and token list with arrow keys ([f25c2d6](https://github.com/outerstudio/trayotp/commit/f25c2d6e2da9acf2b48e384ed81f847bde331aff))

### Bug Fixes

* **ui:** use device-neutral unlock labels ([8cebac6](https://github.com/outerstudio/trayotp/commit/8cebac6928eb79a3527b0cfa53f0c1925bf2df05))
