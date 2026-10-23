#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
version=$(sed -n 's/^version:[[:space:]]*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' "$root/pubspec.yaml" | head -n 1)
if [ -z "$version" ]; then
  echo 'No version found in pubspec.yaml' >&2
  exit 1
fi
app_id='io.github.laith343.openx11se'
arch=x86_64

cd "$root"
flutter build linux --release

bundle="build/linux/x64/release/bundle"
out="build/linux-release"
appimage="OpenX11SE-Linux-$version-$arch.AppImage"
mkdir -p "$out"
rm -f "$out/$appimage" "$out/$appimage.sha256"

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

tool="${APPIMAGETOOL:-}"
if [ -z "$tool" ]; then
  tool="$stage/appimagetool"
  curl -fsSL -o "$tool" "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$arch.AppImage"
  chmod +x "$tool"
fi

appdir="$stage/OpenX11SE.AppDir"
mkdir -p "$appdir/usr/bin" "$appdir/usr/share/applications" "$appdir/usr/share/icons/hicolor/256x256/apps"
cp -R "$bundle/." "$appdir/usr/bin/"
cp "linux/packaging/$app_id.desktop" "$appdir/usr/share/applications/"
cp "linux/packaging/$app_id.desktop" "$appdir/"
cp "linux/packaging/$app_id.png" "$appdir/usr/share/icons/hicolor/256x256/apps/"
cp "linux/packaging/$app_id.png" "$appdir/"
cp linux/packaging/70-openx11se.rules "$appdir/"
ln -s "$app_id.png" "$appdir/.DirIcon"
cat > "$appdir/AppRun" <<'EOF'
#!/bin/sh
here=$(dirname "$(readlink -f "$0")")
exec "$here/usr/bin/openx11se" "$@"
EOF
chmod +x "$appdir/AppRun"

# CI runners have no FUSE, so let appimagetool unpack itself instead of mounting.
APPIMAGE_EXTRACT_AND_RUN=1 ARCH="$arch" "$tool" --no-appstream "$appdir" "$out/$appimage"

(cd "$out" && sha256sum "$appimage" > "$appimage.sha256")
echo "$out/$appimage"
