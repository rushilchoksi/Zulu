# Zulu

A macOS menu bar clock that keeps your local time and UTC side by side, so you
never have to do the conversion in your head when you're working against servers.

<p align="center">
  <img src="docs/menubar.png" alt="Zulu in the macOS menu bar" width="320">
</p>

Named after *Zulu time* — the aviation and military name for UTC.

## Features

- **Always visible.** Local time and UTC sit in the menu bar, in monospaced
  digits so the text doesn't jitter as the numbers tick over.
- **More zones when you need them.** Add any IANA time zone; each one shows its
  time, date, and offset relative to you. Pin the ones you care about into the
  menu bar itself.
- **Copy the formats you actually paste.** One click copies an ISO 8601 UTC
  stamp or a Unix epoch — the two things that usually end up in a query or a
  log filter.
- **Stays out of the way.** No dock icon, no window, no dependencies. The whole
  app is one Swift file and a `swiftc` invocation.

## Install

Requires macOS 13 or later and the Xcode Command Line Tools
(`xcode-select --install`).

```sh
git clone https://github.com/rushilchoksi/zulu.git
cd zulu
./build.sh
```

`build.sh` compiles the app, assembles the bundle, installs it to
`~/Applications`, and launches it. Look at the right side of your menu bar.

To build without installing:

```sh
NO_INSTALL=1 ./build.sh          # leaves Zulu.app in ./build
INSTALL_DIR=/Applications ./build.sh   # or install somewhere else
```

## Usage

Click the menu bar item for the full readout:

```
PDT   15:32:06   Mon 24 Aug   local
UTC   22:32:06   Mon 24 Aug   +7h
IST   04:02:06   Tue 25 Aug   +12h30m

ISO  2026-08-24T22:32:06Z
EPOCH 1787956326
```

Clicking any row copies that timestamp to the clipboard.

- **Time Zones → Add Time Zone** — pick from a common list or browse all IANA
  zones by region.
- **Time Zones → *(a zone)* → Show in Menu Bar** — pin it next to local and UTC.
- **Display** — toggle 24-hour clock, seconds, the date, and whether local time
  or UTC appear in the bar.
- **Start at Login** — registers the app with macOS via `SMAppService`.

Preferences persist in `UserDefaults` under `com.rushilchoksi.zulu`.

## Notes

The app is signed ad-hoc during the build. That's enough for local use, but
macOS may still ask you to approve **Start at Login** the first time, under
System Settings → General → Login Items.

## License

MIT — see [LICENSE](LICENSE).
