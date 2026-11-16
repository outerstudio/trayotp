# TrayOTP

A macOS menu bar authenticator. Click the tray icon to see your one-time codes, click a code to copy it.
Imports and exports 2FAS backups (`.2fas`) and Aegis vaults (`.json`), plain or password-encrypted, and
Ente Auth plain-text exports (`.txt`). Groups carry over (as Ente tags for Ente); icons carry over to and from Aegis.

Requires macOS 14+. Builds with the **Command Line Tools only**, no Xcode needed.

## Develop

```sh
make test   # swift run -c release OTPCoreTests: RFC vectors, otpauth://, 2FAS/Aegis/Ente imports
make run    # build TrayOTP.app (ad-hoc signed), quit the old one, launch
make release
```

`XCTest` ships only with Xcode, so tests are a small executable (`Sources/OTPCoreTests/main.swift`).

## Layout

```
Sources/OTPCore/       pure logic, no UI
  OTP.swift            HOTP / TOTP / Steam codes (CryptoKit)
  Base32.swift         lenient Base32
  OTPAuthURI.swift     otpauth:// parse + build, raw secret input
  TwoFAS.swift         2FAS backup import/export (PBKDF2-SHA256 + AES-256-GCM)
Sources/TrayOTP/       SwiftUI MenuBarExtra app
  AppState.swift       lock state, tokens, import/export
  VaultStore.swift     AES-GCM vault file + key in the Keychain
  Views/               panel, rows, countdown ring, lock and add screens
Scripts/bundle.sh      swift build → TrayOTP.app → codesign
```

## Service icons

TrayOTP ships no brand logos. It reads [Aegis](https://getaegis.app)-format icon packs instead:

1. Download `aegis-icons.zip` from [aegis-icons releases](https://github.com/aegis-icons/aegis-icons/releases).
2. In the tray panel: **⋯ → Install Aegis Icon Pack…** and choose the ZIP.

Tokens get icons automatically by matching their issuer or name ("Google Workspace" → Google).
Right-click a token → **Choose Icon from Pack…** to pick one by hand, or **Set Icon from File…** / **Paste Icon**
for your own image. A chosen icon always wins over the automatic match.
Any ZIP following the [Aegis icon pack format](https://github.com/beemdevelopment/Aegis/blob/master/docs/iconpacks.md)
works (`pack.json` + SVG/PNG/JPEG).

**Fetch Icon from Website…** (right-click a token) downloads the site's favicon from
DuckDuckGo's icon service after you confirm the domain. DuckDuckGo sees that domain. Nothing is fetched
automatically.

Logos are trademarks of their respective owners, used only to identify each service.

## Security model

- Tokens are stored in `~/Library/Application Support/TrayOTP/vault.bin`, encrypted with AES-256-GCM.
  The key is in the Keychain.
- With **Require Touch ID** on (the default), the vault is only decrypted after Touch ID or the Mac password.
  It locks again after the "Stay Unlocked" time, on sleep and on screen lock, and decrypted tokens are dropped from memory.
- **Master password** (optional, ⋯ → Set Master Password…): the vault key in the Keychain is itself encrypted
  with scrypt(password) (N=2^17, r=8, p=1; ~0.5 s and 128 MB per guess) + AES-256-GCM, so the Keychain item
  alone can't open the vault. Unlocking then asks for the password instead of Touch ID. Setting, changing or
  removing it switches to a fresh vault key, so old Keychain copies in backups stop working.
  Forget it and the tokens are gone: keep an encrypted export.
- Exporting and deleting a token always ask for Touch ID or the Mac password again, even while unlocked.
- Copied codes are marked concealed (clipboard managers skip them) and cleared after 30 s.
- Builds use the hardened runtime (also ad-hoc ones), which blocks code injection and debugger attach.
- Limitation: without an Apple-issued certificate the app cannot use the data-protection keychain, so the
  vault key can't be bound to Touch ID at the Keychain level. Touch ID is enforced by the app, and another
  app asking for the key gets a macOS "wants to use your keychain" prompt. Never choose Always Allow for
  anything other than TrayOTP.
- Development builds are ad-hoc signed, so the key goes to the login keychain. macOS may ask
  "TrayOTP wants to use your keychain" after a rebuild; choose **Always Allow**.
  Team-signed builds use the data-protection keychain automatically.

## Release

Push a tag (`git tag v0.1.0 && git push --tags`). `.github/workflows/release.yml` builds a universal app, and,
if the signing secrets listed in the workflow are set, signs it with Developer ID and notarizes it.

## 2FAS format notes

Encrypted backups store `servicesEncrypted` as `cipher:salt:iv` (Base64). The key is PBKDF2-HMAC-SHA256 with
10 000 iterations, the cipher is AES-256-GCM with the 16-byte tag at the end of `cipher`, the salt is 256 bytes
and the IV 12 bytes. `reference` is a fixed string encrypted the same way, used to check the password.
The test fixture `encrypted_test.2fas` (password `example.com`) comes from
[elliotwutingfeng/2fas-backup-decryptor](https://github.com/elliotwutingfeng/2fas-backup-decryptor).
