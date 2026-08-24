import SwiftUI

/// One time zone in the panel: day-phase glyph, city, offset, time, date.
struct ZoneRow: View {

    let reading: ZoneReading
    let date: Date
    @EnvironmentObject private var prefs: Preferences

    var onRemove: (() -> Void)?
    var onTogglePin: (() -> Void)?
    var isPinned = false

    @State private var hovering = false

    private var phase: DayPhase { reading.phase(at: date) }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(phase.color.opacity(0.16))
                Image(systemName: phase.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(phase.color)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(reading.city)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Pill(text: TimeKit.offsetVsLocal(reading.timeZone, at: date),
                         tint: .accentColor, prominent: true)
                }
                Text(TimeKit.subtitle(for: reading.timeZone, at: date))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if hovering, onRemove != nil {
                HStack(spacing: 1) {
                    IconButton(symbol: isPinned ? "pin.fill" : "pin",
                               help: isPinned ? "Remove from menu bar" : "Show in menu bar",
                               tint: isPinned ? .accentColor : .secondary) { onTogglePin?() }
                    IconButton(symbol: "xmark", help: "Remove \(reading.city)") { onRemove?() }
                }
                .transition(.opacity)
            } else {
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(TimeKit.time(date, reading.timeZone,
                                          h24: prefs.use24Hour, seconds: prefs.showSeconds))
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .monospacedDigit()
                        if !prefs.use24Hour {
                            Text(TimeKit.meridiem(date, reading.timeZone, h24: false))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 4) {
                        if reading.dayDelta(at: date) != 0 {
                            Pill(text: reading.dayDelta(at: date) > 0 ? "next day" : "prev day",
                                 tint: .orange, prominent: true)
                        }
                        Text(TimeKit.string(date, reading.timeZone, "EEE d MMM"))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.06 : 0.03))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(phase.color.opacity(0.7))
                .frame(width: 2.5, height: 18)
                .offset(x: -1)
        }
        .onHover { value in
            withAnimation(.easeOut(duration: 0.12)) { hovering = value }
        }
        .help(reading.timeZone.identifier)
    }
}
