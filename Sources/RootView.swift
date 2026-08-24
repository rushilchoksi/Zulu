import SwiftUI

/// The popover: local time as the hero, a scrubbable timeline, and every
/// tracked zone reading the same instant.
struct RootView: View {

    @EnvironmentObject private var prefs: Preferences
    @EnvironmentObject private var clock: Clock

    private enum Pane { case zones, add, settings }
    @State private var pane: Pane = .zones

    private var shown: Date { clock.displayed }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            header
            scrubber

            switch pane {
            case .zones:    zoneList
            case .add:      ZonePicker { withAnimation(.snappy(duration: 0.22)) { pane = .zones } }
            case .settings: SettingsPane()
            }

            Divider().opacity(0.4)
            footer
        }
        .padding(14)
        .frame(width: 344)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(TimeKit.time(shown, .current, h24: prefs.use24Hour, seconds: prefs.showSeconds))
                        .font(.system(size: 40, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if !prefs.use24Hour {
                        Text(TimeKit.meridiem(shown, .current, h24: false))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(TimeKit.string(shown, .current, "EEEE, d MMMM"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(TimeKit.city(for: .current))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(TimeKit.subtitle(for: .current, at: shown))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Pill(text: "local", tint: .accentColor, prominent: true)
            }
        }
    }

    // MARK: Scrubber

    private var scrubber: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: clock.isScrubbing ? "clock.arrow.2.circlepath" : "clock")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(clock.isScrubbing ? Color.accentColor : .secondary)
                Text(TimeKit.relative(clock.scrub))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(clock.isScrubbing ? Color.accentColor : .secondary)
                Spacer()
                if clock.isScrubbing {
                    Button("Back to now") {
                        withAnimation(.snappy(duration: 0.25)) { clock.resetScrub() }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .transition(.opacity)
                }
            }

            TimeScrubber(offset: $clock.scrub)

            HStack {
                Text("-12h")
                Spacer()
                Text("+12h")
            }
            .font(.system(size: 9))
            .foregroundStyle(.quaternary)
        }
    }

    // MARK: Zones

    private var readings: [ZoneReading] {
        prefs.panelZoneIdentifiers.compactMap { identifier in
            guard let zone = TimeZone(identifier: identifier) else { return nil }
            return ZoneReading(id: identifier, timeZone: zone, isLocal: false)
        }
    }

    private var zoneList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if readings.isEmpty {
                emptyState
            } else {
                VStack(spacing: 3) {
                    ForEach(readings) { reading in
                        ZoneRow(
                            reading: reading,
                            date: shown,
                            onRemove: reading.id == "UTC" ? nil : {
                                withAnimation(.snappy(duration: 0.2)) { prefs.remove(reading.id) }
                            },
                            onTogglePin: { prefs.togglePin(reading.id) },
                            isPinned: prefs.isPinned(reading.id)
                        )
                    }
                }
            }

            VStack(spacing: 3) {
                CopyField(label: "ISO", value: TimeKit.iso(shown))
                CopyField(label: "EPOCH", value: TimeKit.epoch(shown))
            }
            .padding(.top, 2)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 3) {
            Image(systemName: "globe")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No time zones yet")
                .font(.system(size: 12, weight: .medium))
            Text("Add the zones your servers run in.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 4) {
            if pane == .zones {
                footerButton("Add time zone", symbol: "plus") {
                    withAnimation(.snappy(duration: 0.22)) { pane = .add }
                }
                Spacer()
                IconButton(symbol: "gearshape", help: "Settings", tint: .primary) {
                    withAnimation(.snappy(duration: 0.22)) { pane = .settings }
                }
            } else {
                footerButton("Back", symbol: "chevron.left") {
                    withAnimation(.snappy(duration: 0.22)) { pane = .zones }
                }
                Spacer()
            }
        }
    }

    private func footerButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
                Text(title).font(.system(size: 12))
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}
