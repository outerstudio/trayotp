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
