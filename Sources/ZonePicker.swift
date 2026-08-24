import SwiftUI

/// Search-driven time zone picker. Replaces the old nested submenus.
struct ZonePicker: View {

    @EnvironmentObject private var prefs: Preferences
    let onDone: () -> Void

    @State private var query = ""
    @FocusState private var focused: Bool

    private static let suggested = [
        "UTC", "America/Los_Angeles", "America/Denver", "America/Chicago",
        "America/New_York", "America/Sao_Paulo", "Europe/London", "Europe/Berlin",
        "Europe/Paris", "Africa/Johannesburg", "Asia/Dubai", "Asia/Kolkata",
        "Asia/Singapore", "Asia/Shanghai", "Asia/Tokyo", "Australia/Sydney",
        "Pacific/Auckland",
    ]

    private var results: [String] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let pool = trimmed.isEmpty
            ? Self.suggested
            : TimeZone.knownTimeZoneIdentifiers.filter { identifier in
                let haystack = identifier.replacingOccurrences(of: "_", with: " ")
                return haystack.range(of: trimmed, options: .caseInsensitive) != nil
            }.sorted()
        return pool.filter { !prefs.zones.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                TextField("Search cities or regions", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($focused)
                if !query.isEmpty {
                    IconButton(symbol: "xmark.circle.fill", help: "Clear") { query = "" }
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )

            if results.isEmpty {
                Text("No time zones match \(query)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(results.prefix(120), id: \.self) { identifier in
                            ZonePickerRow(identifier: identifier) {
                                prefs.add(identifier)
                                onDone()
                            }
                        }
                    }
                }
                .frame(height: 210)
            }
        }
        .onAppear { focused = true }
    }
}

private struct ZonePickerRow: View {
    let identifier: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        let zone = TimeZone(identifier: identifier)
        Button(action: action) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(zone.map(TimeKit.city) ?? identifier)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(identifier)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if let zone {
                    Text(TimeKit.time(Date(), zone, h24: true, seconds: false))
                        .font(.system(size: 12, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(hovering ? Color.accentColor : Color.secondary.opacity(0.4))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.07 : 0))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
