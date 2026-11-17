#!/usr/bin/env bash
# Downloads real exports from other authenticator apps into ThirdPartyFixtures/ (git-ignored).
# The tests use them to check compatibility with files those apps actually produce.
#
# They are not committed because they come from GPL-3.0 projects:
#   - 2fas-backup-decryptor  https://github.com/elliotwutingfeng/2fas-backup-decryptor
#   - Aegis Authenticator    https://github.com/beemdevelopment/Aegis
#
# Each file is pinned by SHA-256, so an upstream change fails here instead of silently changing the tests.
set -euo pipefail

cd "$(dirname "$0")/.."
DIR=ThirdPartyFixtures
mkdir -p "$DIR"

AEGIS=https://raw.githubusercontent.com/beemdevelopment/Aegis/master/app/src/test/resources/com/beemdevelopment/aegis/importers
FILES=(
  "encrypted_test.2fas|https://raw.githubusercontent.com/elliotwutingfeng/2fas-backup-decryptor/main/test/encrypted_test.2fas|088e37f1bbcb76ab8c718d55fc4c6544971328ff7abf39d7cd4a2c39a72fc6ba"
  "aegis_plain.json|$AEGIS/aegis_plain.json|ff7645d711dd05aa1724975b0aa6f2b82b1911d709330f479c87dd755d7ffe5c"
  "aegis_encrypted.json|$AEGIS/aegis_encrypted.json|bf10ba479062b280753eb47f35c898cc286f8c921118f6d4e68c6af67d055d99"
  "ente_auth.txt|$AEGIS/ente_auth.txt|3bae1bf45e2f1077d98c4ac09be4edff937f04838718a13652272089cf46330d"
  "plain.txt|$AEGIS/plain.txt|46c9ac5a0e5d4667894e7d21a7720814eb6e2314414b47e15315bad44b117120"
  "andotp_plain.json|$AEGIS/andotp_plain.json|1c20c8223fe0aa2a27e051e6ad91afd32e2fcaa745b4711105ff0230da13b7a7"
  "andotp_encrypted.bin|$AEGIS/andotp_encrypted.bin|6187f11929122b2eb0a973b900d650f729a577aef14a7f1da642b3f4a3daf0e0"
  "andotp_encrypted_old.bin|$AEGIS/andotp_encrypted_old.bin|89222749901837cd091b40ca5f6376529b2d6752f71df376ea92d6db6881c88b"
  "bitwarden.json|$AEGIS/bitwarden.json|4a38a35d93a1b00995ace4f27a4ebebd385449a044c3ab8463ad65e836cc8eee"
  "bitwarden.csv|$AEGIS/bitwarden.csv|a5da13e4165a870e1eeeff94b2280cd4548ae92189f5edb7b456bbfc8e781a22"
  "freeotp_plus.json|$AEGIS/freeotp_plus.json|4bc01be0840d7354d427deca0112110b3994af802f846134f71f1fcb311892c7"
  "proton_authenticator.json|$AEGIS/proton_authenticator.json|0827a52eecb3ab36d6440a4abcc9d2d76c2a3bb7b8b566351b9f2ae7957a397c"
  "proton_authenticator_encrypted.json|$AEGIS/proton_authenticator_encrypted.json|7138488e9e00af9ddc4aa3e990c3be7185a821d962972b03ff940a591bc6a7e5"
  "stratum_plain.json|$AEGIS/stratum_plain.json|a04a06323b02b9a95e8b9fa76f8e7113b84d04f965a48d6d367a2339d2329989"
  "stratum_encrypted.bin|$AEGIS/stratum_encrypted.bin|23f73e2d108104193f5436389849fbfb3fd8289137b4ddb7f49f7b528ce9af21"
  "stratum_encrypted_legacy.bin|$AEGIS/stratum_encrypted_legacy.bin|bc29610411f4f2dd1947f6a24c51413911896d9a8b7e691d7d584bbbeee0a7fe"
)

for entry in "${FILES[@]}"; do
  IFS='|' read -r name url sha <<< "$entry"
  file="$DIR/$name"
  if [[ ! -f "$file" ]]; then
    curl -sfL --retry 2 -o "$file.tmp" "$url"
    mv "$file.tmp" "$file"
  fi
  actual="$(shasum -a 256 "$file" | cut -d' ' -f1)"
  if [[ "$actual" != "$sha" ]]; then
    echo "Checksum mismatch for $name (upstream file changed?). Expected $sha, got $actual." >&2
    rm -f "$file"
    exit 1
  fi
done
echo "Test fixtures ready in $DIR/"
