# Zulu

A macOS menu bar clock that keeps your local time and UTC side by side, so you
never have to do the conversion in your head when you're working against servers.

<p align="center">
  <img src="docs/menubar.png" alt="Zulu in the macOS menu bar" width="320">
</p>

Named after *Zulu time*, the aviation and military name for UTC.

## Why

Reading a log timestamp, scheduling a cron, checking when a certificate expires:
all of it happens in UTC, and none of it happens in your head. Zulu keeps both
clocks visible and lets you drag time around to answer "what will that be over
there?" without opening a converter.

## Features

**Always visible.** Local time and UTC sit in the menu bar in monospaced digits,
so the text doesn't jitter as the numbers tick over.

**A scrubbable timeline.** Drag the slider to shift every clock in the panel up
to 12 hours either way, in 15 minute steps. It snaps back to now when you let go
near the middle, and resets when you close the panel. This is the part that
replaces the mental arithmetic: move the handle, read every zone at once.

**Day and night at a glance.** Every zone shows a coloured phase glyph, night
through dawn, morning, afternoon and dusk, plus a "next day" or "prev day" badge
when the calendar date differs from yours. Knowing it is 03:00 tomorrow in Tokyo
matters more than knowing it is +16h.

**Copy the formats you actually paste.** One click copies an ISO 8601 UTC stamp
or a Unix epoch, and both follow the scrubber, so you can copy a timestamp for a
moment three hours from now.

**Search, not submenus.** Adding a zone is a search field over every IANA
identifier, with a live preview of the current time in each result. Pin the ones
you care about into the menu bar next to local and UTC.

**Stays out of the way.** No dock icon, no window, no third party dependencies.

## Install

Requires macOS 14 or later and the Xcode Command Line Tools
(`xcode-select --install`).

```sh
git clone https://github.com/rushilchoksi/Zulu.git
cd Zulu
./build.sh
```

`build.sh` compiles the app, assembles the bundle, installs it to
`~/Applications`, and launches it. Look at the right side of your menu bar.

To build without installing:

```sh
NO_INSTALL=1 ./build.sh                # leaves Zulu.app in ./build
INSTALL_DIR=/Applications ./build.sh   # or install somewhere else
```

## Usage

Click the menu bar item to open the panel. Local time is the hero at the top,
with the timeline underneath and every tracked zone below that.

| Action | Where |
| --- | --- |
| Shift all clocks | Drag the timeline, or click anywhere on the track |
| Return to the present | "Back to now", or just close the panel |
| Copy a timestamp | Click the ISO or EPOCH row |
| Add a zone | "Add time zone", then search |
| Pin a zone to the menu bar | Hover its row, click the pin |
| Remove a zone | Hover its row, click the x |
| Settings | The gear in the bottom right |
| Quit | Right click the menu bar item, or Settings |

Settings covers the 24 hour clock, seconds, whether the date appears in the menu
bar, and whether local time and UTC do. "Start at login" registers the app with
macOS through `SMAppService`.

Preferences persist in `UserDefaults` under `com.rushilchoksi.zulu`.

## Layout

```
Sources/
  main.swift          AppDelegate, status item, popover plumbing
  Preferences.swift   Observable settings backed by UserDefaults
  TimeKit.swift       Clock, zone readings, day phase, formatting
  RootView.swift      The panel
  TimeScrubber.swift  The draggable timeline
  ZoneRow.swift       One zone in the list
  ZonePicker.swift    Search driven zone picker
  SettingsPane.swift  Toggles and app actions
  Components.swift    Small shared views
build.sh              Compiles, bundles, signs, installs
```

There is no Xcode project. `build.sh` calls `swiftc` over `Sources/*.swift` and
assembles the `.app` by hand.

## Notes

The app is signed ad hoc during the build. That's enough for local use, but
macOS may still ask you to approve **Start at login** the first time, under
System Settings > General > Login Items.

## License

MIT, see [LICENSE](LICENSE).
