#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
version=$(sed -n 's/^version:[[:space:]]*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' "$root/pubspec.yaml" | head -n 1)
if [ -z "$version" ]; then
  echo 'No version found in pubspec.yaml' >&2
  exit 1
fi
identity="${MACOS_SIGN_IDENTITY:-OpenX11SE Self-Signed}"

cd "$root"
flutter build macos --release

app="build/macos/Build/Products/Release/OpenX11SE.app"
codesign --force --deep --timestamp=none --sign "$identity" "$app"
codesign --verify --deep --strict "$app"

out="build/macos-release"
zip="OpenX11SE-macOS-$version.zip"
dmg="OpenX11SE-macOS-$version.dmg"
mkdir -p "$out"
rm -f "$out/$zip" "$out/$zip.sha256" "$out/$dmg" "$out/$dmg.sha256"

ditto -c -k --sequesterRsrc --keepParent "$app" "$out/$zip"

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/OpenX11SE.app"
ln -s /Applications "$stage/Applications"
attempt=1
until hdiutil create -volname OpenX11SE -srcfolder "$stage" -fs HFS+ -format UDZO -ov "$out/$dmg"; do
  if [ "$attempt" -ge 3 ]; then
    exit 1
  fi
  attempt=$((attempt + 1))
  sleep 5
done
codesign --force --timestamp=none --sign "$identity" "$out/$dmg"

(cd "$out" && shasum -a 256 "$zip" > "$zip.sha256" && shasum -a 256 "$dmg" > "$dmg.sha256")
echo "$out/$dmg"
echo "$out/$zip"
