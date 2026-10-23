#!/bin/sh
set -eu

repo='LAITH343/OpenX11SE'
app_name='OpenX11SE.app'
linux_app_id='io.github.laith343.openx11se'
udev_rule='70-openx11se.rules'
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

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{ print $1 }'
  else
    fail 'sha256sum or shasum is required'
  fi
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    return 1
  fi
}

# Lets the user at the seat open the mouse without root.
install_udev_rule() {
  rule_dir='/etc/udev/rules.d'
  target_rule="$rule_dir/$udev_rule"
  if [ ! -f "$1" ]; then
    say 'Could not read the device permission rule from the AppImage'
    return
  fi
  if [ -f "$target_rule" ] && cmp -s "$1" "$target_rule"; then
    return
  fi
  say "Adding $target_rule so OpenX11SE can talk to the mouse (needs administrator rights)"
  if as_root mkdir -p "$rule_dir" &&
    as_root cp "$1" "$target_rule" &&
    as_root chmod 644 "$target_rule"; then
    if command -v udevadm >/dev/null 2>&1; then
      as_root udevadm control --reload-rules >/dev/null 2>&1 || true
      as_root udevadm trigger --subsystem-match=hidraw --action=change >/dev/null 2>&1 || true
    fi
  else
    kept="$data_home/OpenX11SE/$udev_rule"
    mkdir -p "${kept%/*}" && cp "$1" "$kept"
    say "Could not add $target_rule; OpenX11SE cannot open the mouse until you run:"
    say "  sudo cp '$kept' $target_rule"
    say '  sudo udevadm control --reload-rules && sudo udevadm trigger'
  fi
}

install_linux() {
  need curl
  [ "$(uname -m)" = 'x86_64' ] || fail "unsupported architecture $(uname -m), only x86_64 is available"

  json=$(release_json)
  image_url=$(asset_url "$json" 'OpenX11SE-Linux-[0-9][0-9.]*-x86_64\.AppImage')
  sum_url=$(asset_url "$json" 'OpenX11SE-Linux-[0-9][0-9.]*-x86_64\.AppImage\.sha256')
  [ -n "$image_url" ] || fail 'the latest release has no Linux AppImage'
  [ -n "$sum_url" ] || fail 'the latest release has no checksum for the Linux AppImage'
  image_name=${image_url##*/}

  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  work=$(mktemp -d)

  say "Downloading $image_name"
  curl -fL --progress-bar -o "$work/$image_name" "$image_url" || fail 'download failed'
  curl -fsSL -o "$work/$image_name.sha256" "$sum_url" || fail 'checksum download failed'

  expected=$(awk 'NF { print tolower($1); exit }' "$work/$image_name.sha256")
  actual=$(sha256 "$work/$image_name")
  [ -n "$expected" ] && [ "$expected" = "$actual" ] || fail 'checksum mismatch, nothing was installed'
  chmod +x "$work/$image_name"

  data_home=${XDG_DATA_HOME:-$HOME/.local/share}
  bin_dir="$HOME/.local/bin"
  target="$bin_dir/OpenX11SE.AppImage"
  icon_dir="$data_home/icons/hicolor/256x256/apps"
  desktop_dir="$data_home/applications"
  mkdir -p "$bin_dir" "$icon_dir" "$desktop_dir"

  extracted="$work/squashfs-root"
  (cd "$work" && "./$image_name" --appimage-extract "$linux_app_id.png" >/dev/null 2>&1) || true
  (cd "$work" && "./$image_name" --appimage-extract "$udev_rule" >/dev/null 2>&1) || true
  if [ -f "$extracted/$linux_app_id.png" ]; then
    cp "$extracted/$linux_app_id.png" "$icon_dir/$linux_app_id.png" || say 'Could not install the icon'
  else
    say 'Could not read the icon from the AppImage, the menu entry will use a generic icon'
  fi
  install_udev_rule "$extracted/$udev_rule"

  uid=$(id -u)
  if pgrep -x -U "$uid" openx11se >/dev/null 2>&1; then
    say 'Closing the running OpenX11SE'
    pkill -x -U "$uid" openx11se >/dev/null 2>&1 || true
    tries=0
    while pgrep -x -U "$uid" openx11se >/dev/null 2>&1; do
      tries=$((tries + 1))
      [ "$tries" -le 50 ] || fail 'OpenX11SE is still running, quit it and run the installer again'
      sleep 0.2
    done
  fi

  if [ -e "$target" ]; then
    say "Updating $target"
  else
    say "Installing to $target"
  fi
  new="$target.new"
  rm -f "$new"
  partial="$new"
  cp "$work/$image_name" "$new" || fail "could not copy $image_name"
  chmod +x "$new"
  mv -f "$new" "$target" || fail "could not replace $target"
  partial=''

  # The AppImage runtime mounts itself with FUSE; without it, unpack on each launch instead.
  exec_line="\"$target\""
  if ! command -v fusermount3 >/dev/null 2>&1 && ! command -v fusermount >/dev/null 2>&1; then
    exec_line="env APPIMAGE_EXTRACT_AND_RUN=1 $exec_line"
    say 'FUSE was not found, OpenX11SE will unpack itself on each launch (install fuse3 for faster startup)'
  fi

  desktop="$desktop_dir/$linux_app_id.desktop"
  cat > "$desktop" <<EOF || fail "could not write $desktop"
[Desktop Entry]
Type=Application
Name=OpenX11SE
Comment=Configure the Attack Shark X11SE mouse
Exec=$exec_line
Icon=$linux_app_id
Terminal=false
Categories=Settings;HardwareSettings;
StartupWMClass=$linux_app_id
EOF
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
  command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t "$data_home/icons/hicolor" >/dev/null 2>&1 || true

  say 'OpenX11SE is installed, find it in your applications menu'
  if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    if [ -z "${exec_line##env *}" ]; then
      APPIMAGE_EXTRACT_AND_RUN=1 nohup "$target" >/dev/null 2>&1 &
    else
      nohup "$target" >/dev/null 2>&1 &
    fi
  fi
}

main() {
  case "$(uname -s)" in
    Darwin)
      install_macos
      ;;
    Linux)
      install_linux
      ;;
    *)
      fail "unsupported system $(uname -s); on Windows use the installer from https://github.com/$repo/releases/latest"
      ;;
  esac
}

main "$@"
