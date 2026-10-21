#!/bin/sh
set -eu

repo='LAITH343/OpenX11SE'
app_name='OpenX11SE.app'
work=''
mount=''
partial=''

cleanup() {
  if [ -n "$mount" ]; then
    hdiutil detach "$mount" -force >/dev/null 2>&1 || true
  fi
  if [ -n "$partial" ]; then
    rm -rf "$partial"
  fi
  if [ -n "$work" ]; then
    rm -rf "$work"
  fi
}

say() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

release_json() {
  curl -fsSL -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/$repo/releases/latest" ||
    fail 'could not read the latest release from GitHub (offline or rate limited), try again later'
}

asset_url() {
  printf '%s\n' "$1" |
    grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*"' |
    sed 's/.*"\(https:[^"]*\)"$/\1/' |
    grep -E "/$2\$" |
    head -n 1
}

install_macos() {
  need curl
  need shasum
  need hdiutil
  need ditto

  json=$(release_json)
  dmg_url=$(asset_url "$json" 'OpenX11SE-macOS-[0-9][0-9.]*\.dmg')
  sum_url=$(asset_url "$json" 'OpenX11SE-macOS-[0-9][0-9.]*\.dmg\.sha256')
  [ -n "$dmg_url" ] || fail 'the latest release has no macOS disk image'
  [ -n "$sum_url" ] || fail 'the latest release has no checksum for the macOS disk image'
  dmg_name=${dmg_url##*/}

  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  work=$(mktemp -d)
  mount="$work/mount"

  say "Downloading $dmg_name"
  curl -fL --progress-bar -o "$work/$dmg_name" "$dmg_url" || fail 'download failed'
  curl -fsSL -o "$work/$dmg_name.sha256" "$sum_url" || fail 'checksum download failed'

  expected=$(awk 'NF { print tolower($1); exit }' "$work/$dmg_name.sha256")
  actual=$(shasum -a 256 "$work/$dmg_name" | awk '{ print $1 }')
  [ -n "$expected" ] && [ "$expected" = "$actual" ] || fail 'checksum mismatch, nothing was installed'

  mkdir -p "$mount"
  hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$mount" "$work/$dmg_name" >/dev/null ||
    fail 'could not open the disk image'
  [ -d "$mount/$app_name" ] || fail "the disk image has no $app_name"

  if [ -e "/Applications/$app_name" ]; then
    target_dir='/Applications'
    [ -w "$target_dir" ] || fail "cannot replace /Applications/$app_name, run the installer as a user who can write to /Applications"
  elif [ -w '/Applications' ]; then
    target_dir='/Applications'
  else
    target_dir="$HOME/Applications"
    mkdir -p "$target_dir"
  fi
  target="$target_dir/$app_name"

  uid=$(id -u)
  if pgrep -x -U "$uid" OpenX11SE >/dev/null 2>&1; then
    say 'Closing the running OpenX11SE'
    osascript -e 'quit app "OpenX11SE"' >/dev/null 2>&1 || true
    tries=0
    while pgrep -x -U "$uid" OpenX11SE >/dev/null 2>&1; do
      tries=$((tries + 1))
      [ "$tries" -le 50 ] || fail 'OpenX11SE is still running, quit it and run the installer again'
      sleep 0.2
    done
  fi

  say "Installing to $target"
  new="$target.new"
  old="$target.old"
  rm -rf "$new" "$old"
  partial="$new"
  ditto "$mount/$app_name" "$new" || fail "could not copy $app_name"
  if [ -e "$target" ]; then
    mv "$target" "$old" || fail "could not replace $target"
  fi
  if ! mv "$new" "$target"; then
    [ -e "$old" ] && mv "$old" "$target"
    fail "could not replace $target"
  fi
  partial=''
  rm -rf "$old"
  xattr -dr com.apple.quarantine "$target" 2>/dev/null || true

  say 'OpenX11SE is installed'
  open "$target"
}

main() {
  case "$(uname -s)" in
    Darwin)
      install_macos
      ;;
    Linux)
      fail 'Linux is not supported yet'
      ;;
    *)
      fail "unsupported system $(uname -s); on Windows use the installer from https://github.com/$repo/releases/latest"
      ;;
  esac
}

main "$@"
