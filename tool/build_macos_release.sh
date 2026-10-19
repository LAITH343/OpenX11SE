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
name="OpenX11SE-macOS-$version.zip"
mkdir -p "$out"
rm -f "$out/$name" "$out/$name.sha256"
ditto -c -k --sequesterRsrc --keepParent "$app" "$out/$name"
(cd "$out" && shasum -a 256 "$name" > "$name.sha256")
echo "$out/$name"
