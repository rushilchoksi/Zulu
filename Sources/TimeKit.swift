import Foundation
import SwiftUI
import Combine

/// Publishes the current instant, plus a scrub offset the UI can drag around.
final class Clock: ObservableObject {
    @Published private(set) var now = Date()
    /// Seconds added to `now` when reading zones in the panel. Zero means "right now".
    @Published var scrub: TimeInterval = 0

    private var timer: Timer?

    init() {
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.now = Date()
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// The instant the panel is displaying: `now` unless the user is scrubbing.
    var displayed: Date { now.addingTimeInterval(scrub) }

    var isScrubbing: Bool { scrub != 0 }

    func resetScrub() { scrub = 0 }
}

// MARK: - Day phase

enum DayPhase {
    case night, dawn, morning, afternoon, dusk

    static func at(_ date: Date, in zone: TimeZone) -> DayPhase {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        switch calendar.component(.hour, from: date) {
        case 0..<5:   return .night
        case 5..<8:   return .dawn
        case 8..<12:  return .morning
        case 12..<18: return .afternoon
        case 18..<21: return .dusk
        default:      return .night
        }
    }

    var color: Color {
        switch self {
        case .night:     return Color(red: 0.42, green: 0.45, blue: 0.78)
        case .dawn:      return Color(red: 0.95, green: 0.60, blue: 0.36)
        case .morning:   return Color(red: 0.36, green: 0.72, blue: 0.94)
        case .afternoon: return Color(red: 0.98, green: 0.78, blue: 0.30)
        case .dusk:      return Color(red: 0.80, green: 0.48, blue: 0.72)
        }
    }

    var symbol: String {
        switch self {
        case .night:     return "moon.stars.fill"
        case .dawn:      return "sunrise.fill"
        case .morning:   return "sun.max.fill"
        case .afternoon: return "sun.max.fill"
        case .dusk:      return "sunset.fill"
        }
    }
}

// MARK: - A single zone being displayed

struct ZoneReading: Identifiable {
    let id: String
    let timeZone: TimeZone
    let isLocal: Bool

    var city: String { TimeKit.city(for: timeZone) }

    func phase(at date: Date) -> DayPhase { DayPhase.at(date, in: timeZone) }

    /// Whether the instant falls inside a conventional 9 to 6 working weekday.
    func isWorkingHours(at date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)
        return (2...6).contains(weekday) && (9..<18).contains(hour)
    }

    /// Calendar days this zone is ahead of / behind the local zone: -1, 0, or +1.
    func dayDelta(at date: Date) -> Int {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = .current
        var remote = Calendar(identifier: .gregorian)
        remote.timeZone = timeZone
        let localDay = local.dateComponents([.year, .month, .day], from: date)
        let remoteDay = remote.dateComponents([.year, .month, .day], from: date)
        guard let l = local.date(from: localDay), let r = remote.date(from: remoteDay) else { return 0 }
        return local.dateComponents([.day], from: l, to: r).day ?? 0
    }
}

// MARK: - Formatting

enum TimeKit {
    private static var cache: [String: DateFormatter] = [:]

    static func formatter(_ pattern: String, _ zone: TimeZone) -> DateFormatter {
        let key = "\(zone.identifier)|\(pattern)"
        if let cached = cache[key] { return cached }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = pattern
        cache[key] = formatter
        return formatter
    }

    static func string(_ date: Date, _ zone: TimeZone, _ pattern: String) -> String {
        formatter(pattern, zone).string(from: date)
    }

    /// "15:32" or "3:32 PM", with optional seconds.
    static func time(_ date: Date, _ zone: TimeZone, h24: Bool, seconds: Bool) -> String {
        let pattern: String
        switch (h24, seconds) {
        case (true, false):  pattern = "HH:mm"
        case (true, true):   pattern = "HH:mm:ss"
        case (false, false): pattern = "h:mm"
        case (false, true):  pattern = "h:mm:ss"
        }
        return string(date, zone, pattern)
    }

    /// "PM" / "AM", or empty on a 24-hour clock.
    static func meridiem(_ date: Date, _ zone: TimeZone, h24: Bool) -> String {
        h24 ? "" : string(date, zone, "a")
    }

    /// Short uppercase tag: "UTC", "PDT", "JST", or a city stub.
    static func tag(for zone: TimeZone) -> String {
        if zone.identifier == "UTC" || zone.identifier == "GMT" { return "UTC" }
        let abbreviation = zone.abbreviation() ?? ""
        if abbreviation.range(of: "^[A-Za-z]{2,5}$", options: .regularExpression) != nil {
            return abbreviation.uppercased()
        }
        return String(city(for: zone).replacingOccurrences(of: " ", with: "").prefix(3)).uppercased()
    }

    /// "Los Angeles" from "America/Los_Angeles".
    static func city(for zone: TimeZone) -> String {
        if zone.identifier == "UTC" || zone.identifier == "GMT" { return "UTC" }
        let last = zone.identifier.split(separator: "/").last.map(String.init) ?? zone.identifier
        return last.replacingOccurrences(of: "_", with: " ")
    }

    /// "UTC+05:30"
    static func utcOffset(_ zone: TimeZone, at date: Date) -> String {
        let seconds = zone.secondsFromGMT(for: date)
        if seconds == 0 { return "UTC" }
        let sign = seconds < 0 ? "-" : "+"
        let magnitude = abs(seconds)
        let hours = magnitude / 3600
        let minutes = (magnitude % 3600) / 60
        return minutes == 0
            ? "UTC\(sign)\(hours)"
            : String(format: "UTC%@%d:%02d", sign, hours, minutes)
    }

    /// Zone caption for a row: "PDT · UTC-7", or a spelled-out name when the
    /// tag and the offset would just repeat each other (UTC).
    static func subtitle(for zone: TimeZone, at date: Date) -> String {
        let tag = self.tag(for: zone)
        let offset = utcOffset(zone, at: date)
        if tag == offset { return "Coordinated Universal Time" }
        return "\(tag) · \(offset)"
    }

    /// Offset relative to the local zone: "+7h", "-3h30m", "same time".
    static func offsetVsLocal(_ zone: TimeZone, at date: Date) -> String {
        let delta = zone.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)
        if delta == 0 { return "same time" }
        let sign = delta < 0 ? "-" : "+"
        let magnitude = abs(delta)
        let hours = magnitude / 3600
        let minutes = (magnitude % 3600) / 60
        return minutes == 0 ? "\(sign)\(hours)h" : "\(sign)\(hours)h\(minutes)m"
    }

    /// "in 3h 30m" / "3h ago" / "now", describing the scrub offset.
    static func relative(_ offset: TimeInterval) -> String {
        if abs(offset) < 60 { return "Now" }
        let magnitude = abs(offset)
        let hours = Int(magnitude) / 3600
        let minutes = (Int(magnitude) % 3600) / 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours)h") }
        if minutes > 0 { parts.append("\(minutes)m") }
        let span = parts.joined(separator: " ")
        return offset < 0 ? "\(span) ago" : "in \(span)"
    }

    static func iso(_ date: Date) -> String {
        string(date, TimeZone(identifier: "UTC")!, "yyyy-MM-dd'T'HH:mm:ss'Z'")
    }

    static func epoch(_ date: Date) -> String {
        String(Int(date.timeIntervalSince1970))
    }
}
