import Foundation
import Combine

/// User-facing settings, persisted to `UserDefaults` and observable by SwiftUI.
final class Preferences: ObservableObject {

    private enum Key {
        static let use24Hour   = "use24Hour"
        static let showSeconds = "showSeconds"
        static let showDate    = "showDateInBar"
        static let showLocal   = "showLocalInBar"
        static let showUTC     = "showUTCInBar"
        static let zones       = "extraZones"
        static let pinned      = "pinnedZones"
    }

    private let store: UserDefaults

    @Published var use24Hour: Bool    { didSet { store.set(use24Hour, forKey: Key.use24Hour) } }
    @Published var showSeconds: Bool  { didSet { store.set(showSeconds, forKey: Key.showSeconds) } }
    @Published var showDate: Bool     { didSet { store.set(showDate, forKey: Key.showDate) } }
    @Published var showLocal: Bool    { didSet { store.set(showLocal, forKey: Key.showLocal) } }
    @Published var showUTC: Bool      { didSet { store.set(showUTC, forKey: Key.showUTC) } }
    @Published var zones: [String]    { didSet { store.set(zones, forKey: Key.zones) } }
    @Published var pinned: [String]   { didSet { store.set(pinned, forKey: Key.pinned) } }

    init(store: UserDefaults = .standard) {
        self.store = store
        store.register(defaults: [
            Key.use24Hour: true,
            Key.showSeconds: false,
            Key.showDate: false,
            Key.showLocal: true,
            Key.showUTC: true,
            Key.zones: [String](),
            Key.pinned: [String](),
        ])
        use24Hour   = store.bool(forKey: Key.use24Hour)
        showSeconds = store.bool(forKey: Key.showSeconds)
        showDate    = store.bool(forKey: Key.showDate)
        showLocal   = store.bool(forKey: Key.showLocal)
        showUTC     = store.bool(forKey: Key.showUTC)
        zones       = store.stringArray(forKey: Key.zones) ?? []
        pinned      = store.stringArray(forKey: Key.pinned) ?? []
    }

    // MARK: Zone management

    func add(_ identifier: String) {
        guard !zones.contains(identifier), TimeZone(identifier: identifier) != nil else { return }
        zones.append(identifier)
    }

    func remove(_ identifier: String) {
        zones.removeAll { $0 == identifier }
        pinned.removeAll { $0 == identifier }
    }

    func isPinned(_ identifier: String) -> Bool { pinned.contains(identifier) }

    func togglePin(_ identifier: String) {
        if let index = pinned.firstIndex(of: identifier) {
            pinned.remove(at: index)
        } else {
            pinned.append(identifier)
        }
    }

    /// Zones shown in the menu bar, in display order.
    var barZoneIdentifiers: [String] {
        var result: [String] = []
        if showLocal { result.append(TimeZone.current.identifier) }
        if showUTC, TimeZone.current.identifier != "UTC" { result.append("UTC") }
        result.append(contentsOf: pinned)
        return result.isEmpty ? [TimeZone.current.identifier] : result
    }

    /// Zones shown in the popover, in display order.
    var panelZoneIdentifiers: [String] {
        var result = ["UTC"]
        if TimeZone.current.identifier == "UTC" { result = [] }
        result.append(contentsOf: zones.filter { $0 != "UTC" })
        return result
    }
}
