# Hardware test checklist

Run every item twice: once over the USB-C cable and once over the 2.4 GHz dongle (switch on the
underside set to 2.4G). Run the full list for every build: Windows, macOS and Linux (AppImage).

Record the build, firmware version and date for each run.

| Build | Link | Firmware | Date | Tester |
|---|---|---|---|---|
| Windows | Cable | | | |
| Windows | Dongle | | | |
| macOS | Cable | | | |
| macOS | Dongle | | | |
| Linux | Cable | | | |
| Linux | Dongle | | | |

## 1. Connection

- [ ] Start with no device connected: the "Connect your X11SE" state is shown.
- [ ] Windows, macOS and Linux: plugging in the cable or dongle loads the settings within about 2 s without a click.
- [ ] Linux: without the udev rule, the "not allowed to open the mouse" message is shown.
- [ ] Header shows Wired or 2.4 GHz and the firmware version.
- [ ] With the cable and the dongle both connected, the cable is used.

## 2. Snapshot read

- [ ] DPI stages, active stage, polling rate, lighting, power and buttons match the vendor app.
- [ ] Factory state reads as 6 stages 800..22000, stage 3 active, 1000 Hz, buttons L/R/M/Forward/Back.

## 3. Live notifications

- [ ] Battery percentage appears in the header and updates over time.
- [ ] Charging state changes when the cable is plugged in and out (dongle link).
- [ ] Pressing the DPI button updates the "On the mouse" widget and shows a toast.
- [ ] Dongle: leaving the mouse idle shows the asleep state; moving it reloads without a click.
- [ ] Dongle: switching the mouse off shows the mouse-off state; switching it on reloads.

## 4. Apply and read-back per section

For each item: change the value, Apply, unplug and reconnect (or reload), and confirm the read-back.

- [ ] Performance: DPI value of a stage, stage colour, enable/disable a stage, active stage.
- [ ] Performance: polling rate 125 / 250 / 500 / 1000 Hz.
- [ ] Performance: angle snap and ripple control.
- [ ] Buttons: remap Forward to a keyboard shortcut (for example Ctrl + C) and test it.
- [ ] Buttons: remap a button to a media key and test it; reset all.
- [ ] Lighting: every mode visibly matches on the LED; brightness 2 is dimmer than 8.
- [ ] Power: sleep and deep-sleep minutes and debounce round-trip.
- [ ] Apply progress advances report by report and ends with a "saved" toast.

## 5. Macros

- [ ] Record a macro, save it, assign it to Forward with "Play 3 times", Apply.
- [ ] The macro plays on the mouse as recorded.
- [ ] The capacity indicator blocks saving over the limit.

## 6. Profiles

- [ ] Create, duplicate, rename and delete a profile.
- [ ] Switching profile and applying updates the mouse.
- [ ] Profiles survive an app restart.
- [ ] Export a profile to a file and import it back.
- [ ] Import from the vendor software reproduces the vendor profile values.

## 7. Restore defaults

- [ ] Settings > Restore mouse to factory defaults asks for confirmation, resets the mouse and the
      read-back matches the factory state.

## 8. Failure handling

- [ ] Unplug the cable during Apply: the write error banner appears, staged edits are kept, and
      Retry after reconnecting succeeds.
- [ ] Remove the dongle during an edit: the disconnected banner appears and edits are kept.
- [ ] Dongle with the mouse asleep: Apply shows "Mouse is asleep - move it, then Retry".
- [ ] No crash or blank screen in any of the above.

## 9. Packaging

- [ ] The Windows installer installs without an administrator prompt and starts the app.
- [ ] "Start with system" launches the app minimised after signing in again.
- [ ] Uninstalling removes the app and its startup entry.
- [ ] macOS and Linux: `install.sh` installs the app, and running it again updates it in place.
- [ ] Linux: the menu entry starts the app, and opening it again brings back the hidden window.
