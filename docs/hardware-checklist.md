# Hardware test checklist

Run every item twice: once over the USB-C cable and once over the 2.4 GHz dongle (switch on the
underside set to 2.4G). Run the full list for both builds: Windows desktop and Web (Chrome or Edge).

Record the build, firmware version and date for each run.

| Build | Link | Firmware | Date | Tester |
|---|---|---|---|---|
| Windows | Cable | | | |
| Windows | Dongle | | | |
| Web | Cable | | | |
| Web | Dongle | | | |

## 1. Connection

- [ ] Start with no device connected: the "Connect your X11SE" state is shown.
- [ ] Windows: plugging in the cable or dongle loads the settings within about 2 s without a click.
- [ ] Web: "Connect device" opens the browser prompt; choosing X11SE loads the settings.
- [ ] Web: reloading the page reconnects to the granted device without the prompt.
- [ ] Web: opening the page in Firefox or Safari shows the unsupported-browser state.
- [ ] Web: opening the page over plain `http://` (not localhost) shows the secure-connection state.
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
- [ ] Profiles survive an app restart (Windows) and a page reload (Web).
- [ ] Export a profile to a file and import it back.
- [ ] Windows: import from the vendor software reproduces the vendor profile values.

## 7. Restore defaults

- [ ] Settings > Restore mouse to factory defaults asks for confirmation, resets the mouse and the
      read-back matches the factory state.

## 8. Failure handling

- [ ] Unplug the cable during Apply: the write error banner appears, staged edits are kept, and
      Retry after reconnecting succeeds.
- [ ] Remove the dongle during an edit: the disconnected banner appears and edits are kept.
- [ ] Dongle with the mouse asleep: Apply shows "Mouse is asleep - move it, then Retry".
- [ ] Web: with the vendor software or another tab holding the device, the open failure message is shown.
- [ ] No crash or blank screen in any of the above.

## 9. Packaging

- [ ] The Windows installer installs without an administrator prompt and starts the app.
- [ ] "Start with system" launches the app minimised after signing in again.
- [ ] Uninstalling removes the app and its startup entry.
- [ ] The web build served as static files loads and keeps its data after a reload.
