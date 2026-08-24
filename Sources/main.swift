import AppKit
import ServiceManagement

// MARK: - Preferences

let store = UserDefaults.standard

enum Pref {
    static let use24Hour   = "use24Hour"
    static let showSeconds = "showSeconds"
    static let showDate    = "showDateInBar"
    static let showLocal   = "showLocalInBar"
    static let showUTC     = "showUTCInBar"
    static let zones       = "extraZones"
    static let pinned      = "pinnedZones"

    static func registerAll() {
        store.register(defaults: [
            use24Hour: true,
            showSeconds: false,
            showDate: false,
            showLocal: true,
            showUTC: true,
            zones: [String](),
            pinned: [String](),
        ])
    }

    static func flag(_ key: String) -> Bool { store.bool(forKey: key) }
    static func toggle(_ key: String) { store.set(!store.bool(forKey: key), forKey: key) }
    static func list(_ key: String) -> [String] { store.stringArray(forKey: key) ?? [] }
    static func setList(_ key: String, _ value: [String]) { store.set(value, forKey: key) }
}

// MARK: - Formatting

enum Fmt {
    private static var cache: [String: DateFormatter] = [:]

    static func formatter(_ pattern: String, _ tz: TimeZone) -> DateFormatter {
        let key = "\(tz.identifier)|\(pattern)"
        if let cached = cache[key] { return cached }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = tz
        df.dateFormat = pattern
        cache[key] = df
        return df
    }

    /// Short uppercase tag for a zone: "UTC", "PDT", "JST", or a city stub.
    static func tag(for tz: TimeZone) -> String {
        if tz.identifier == "UTC" || tz.identifier == "GMT" { return "UTC" }
        let abbr = tz.abbreviation() ?? ""
        if abbr.range(of: "^[A-Za-z]{2,5}$", options: .regularExpression) != nil {
            return abbr.uppercased()
        }
        let city = tz.identifier.split(separator: "/").last.map(String.init) ?? tz.identifier
        return String(city.replacingOccurrences(of: "_", with: "").prefix(3)).uppercased()
    }

    static func timePattern(seconds: Bool, h24: Bool) -> String {
        switch (h24, seconds) {
        case (true, false):  return "HH:mm"
        case (true, true):   return "HH:mm:ss"
        case (false, false): return "h:mm a"
        case (false, true):  return "h:mm:ss a"
        }
    }

    static func time(_ date: Date, _ tz: TimeZone, seconds: Bool, h24: Bool) -> String {
        formatter(timePattern(seconds: seconds, h24: h24), tz).string(from: date)
    }

    static func date(_ date: Date, _ tz: TimeZone, pattern: String = "EEE d MMM") -> String {
        formatter(pattern, tz).string(from: date)
    }

    /// Offset of `tz` relative to the machine's local zone, e.g. "+3h30m", "-8h", "same".
    static func offsetVsLocal(_ tz: TimeZone, at date: Date) -> String {
        let delta = tz.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)
        if delta == 0 { return "same" }
        let sign = delta < 0 ? "-" : "+"
        let abs = Swift.abs(delta)
        let hours = abs / 3600
        let minutes = (abs % 3600) / 60
        return minutes == 0 ? "\(sign)\(hours)h" : "\(sign)\(hours)h\(minutes)m"
    }

    /// UTC offset of the zone itself, e.g. "UTC+05:30".
    static func utcOffset(_ tz: TimeZone, at date: Date) -> String {
        let secs = tz.secondsFromGMT(for: date)
        let sign = secs < 0 ? "-" : "+"
        let abs = Swift.abs(secs)
        return String(format: "UTC%@%02d:%02d", sign, abs / 3600, (abs % 3600) / 60)
    }

    static func pad(_ s: String, _ width: Int) -> String {
        s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
    }
}

// MARK: - App

final class ZuluApp: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var barTimer: Timer?
    private var menuTimer: Timer?
    private var lastBarTitle = ""

    /// Menu rows whose titles are re-rendered every tick while the menu is open.
    private var liveRows: [(item: NSMenuItem, tz: TimeZone, isLocal: Bool)] = []
    private var isoRow: NSMenuItem?
    private var epochRow: NSMenuItem?

    private var commonZones: [String] {
        ["UTC", "America/Los_Angeles", "America/Denver", "America/Chicago",
         "America/New_York", "America/Sao_Paulo", "Europe/London", "Europe/Berlin",
         "Europe/Paris", "Africa/Johannesburg", "Asia/Dubai", "Asia/Kolkata",
         "Asia/Singapore", "Asia/Shanghai", "Asia/Tokyo", "Australia/Sydney",
         "Pacific/Auckland"]
    }

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        Pref.registerAll()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu.delegate = self
        statusItem.menu = menu

        renderBar()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.renderBar() }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        barTimer = timer

        // Redraw when the machine's own zone changes (travel, DST, manual change).
        NotificationCenter.default.addObserver(
            self, selector: #selector(zoneChanged),
            name: NSNotification.Name.NSSystemTimeZoneDidChange, object: nil)
    }

    @objc private func zoneChanged() {
        lastBarTitle = ""
        renderBar()
    }

    // MARK: Menu bar title

    private func barZones() -> [TimeZone] {
        var zones: [TimeZone] = []
        if Pref.flag(Pref.showLocal) { zones.append(TimeZone.current) }
        if Pref.flag(Pref.showUTC), let utc = TimeZone(identifier: "UTC") { zones.append(utc) }
        for id in Pref.list(Pref.pinned) {
            if let tz = TimeZone(identifier: id) { zones.append(tz) }
        }
        return zones.isEmpty ? [TimeZone.current] : zones
    }

    private func renderBar() {
        let now = Date()
        let seconds = Pref.flag(Pref.showSeconds)
        let h24 = Pref.flag(Pref.use24Hour)

        let segments = barZones().map { tz -> String in
            "\(Fmt.tag(for: tz)) \(Fmt.time(now, tz, seconds: seconds, h24: h24))"
        }
        var title = segments.joined(separator: "  ·  ")
        if Pref.flag(Pref.showDate) {
            title = "\(Fmt.date(now, TimeZone.current))  " + title
        }

        guard title != lastBarTitle else { return }
        lastBarTitle = title
        statusItem.button?.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)])
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        rebuildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.refreshLiveRows() }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        menuTimer = timer
    }

    func menuDidClose(_ menu: NSMenu) {
        menuTimer?.invalidate()
        menuTimer = nil
    }

    private func menuZones() -> [(TimeZone, Bool)] {
        var zones: [(TimeZone, Bool)] = [(TimeZone.current, true)]
        if let utc = TimeZone(identifier: "UTC"), TimeZone.current.identifier != "UTC" {
            zones.append((utc, false))
        }
        for id in Pref.list(Pref.zones) {
            if let tz = TimeZone(identifier: id) { zones.append((tz, false)) }
        }
        return zones
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        liveRows.removeAll()

        for (tz, isLocal) in menuZones() {
            let item = NSMenuItem(title: "", action: #selector(copyZoneTime(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = tz.identifier
            item.toolTip = "\(tz.identifier) — click to copy"
            menu.addItem(item)
            liveRows.append((item, tz, isLocal))
        }
        refreshLiveRows()

        menu.addItem(.separator())

        let iso = NSMenuItem(title: "", action: #selector(copyISO(_:)), keyEquivalent: "")
        iso.target = self
        menu.addItem(iso)
        isoRow = iso

        let epoch = NSMenuItem(title: "", action: #selector(copyEpoch(_:)), keyEquivalent: "")
        epoch.target = self
        menu.addItem(epoch)
        epochRow = epoch
        refreshStampRows()

        menu.addItem(.separator())

        let zonesItem = NSMenuItem(title: "Time Zones", action: nil, keyEquivalent: "")
        zonesItem.submenu = buildZonesMenu()
        menu.addItem(zonesItem)

        let displayItem = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
        displayItem.submenu = buildDisplayMenu()
        menu.addItem(displayItem)

        let login = NSMenuItem(title: "Start at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Zulu", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func refreshLiveRows() {
        let now = Date()
        let h24 = Pref.flag(Pref.use24Hour)
        let mono = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let monoBold = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)

        for row in liveRows {
            let tag = Fmt.pad(Fmt.tag(for: row.tz), 5)
            let time = Fmt.pad(Fmt.time(now, row.tz, seconds: true, h24: h24), h24 ? 10 : 13)
            let date = Fmt.pad(Fmt.date(now, row.tz), 12)
            let trail = row.isLocal ? "local" : Fmt.offsetVsLocal(row.tz, at: now)
            row.item.attributedTitle = NSAttributedString(
                string: tag + time + date + trail,
                attributes: [.font: row.isLocal ? monoBold : mono])
        }
        refreshStampRows()
    }

    private func refreshStampRows() {
        let now = Date()
        let mono = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let isoText = Fmt.formatter("yyyy-MM-dd'T'HH:mm:ss'Z'", TimeZone(identifier: "UTC")!).string(from: now)
        isoRow?.attributedTitle = NSAttributedString(
            string: Fmt.pad("ISO", 5) + isoText, attributes: [.font: mono])
        epochRow?.attributedTitle = NSAttributedString(
            string: Fmt.pad("EPOCH", 5) + String(Int(now.timeIntervalSince1970)), attributes: [.font: mono])
    }

    // MARK: Submenus

    private func buildZonesMenu() -> NSMenu {
        let root = NSMenu()

        let add = NSMenuItem(title: "Add Time Zone", action: nil, keyEquivalent: "")
        add.submenu = buildPickerMenu()
        root.addItem(add)

        let added = Pref.list(Pref.zones)
        if !added.isEmpty {
            root.addItem(.separator())
            let pinned = Set(Pref.list(Pref.pinned))
            for id in added {
                let item = NSMenuItem(title: id, action: nil, keyEquivalent: "")
                let sub = NSMenu()

                let pin = NSMenuItem(title: "Show in Menu Bar", action: #selector(togglePin(_:)), keyEquivalent: "")
                pin.target = self
                pin.representedObject = id
                pin.state = pinned.contains(id) ? .on : .off
                sub.addItem(pin)

                sub.addItem(.separator())
                let remove = NSMenuItem(title: "Remove", action: #selector(removeZone(_:)), keyEquivalent: "")
                remove.target = self
                remove.representedObject = id
                sub.addItem(remove)

                item.submenu = sub
                root.addItem(item)
            }
        }
        return root
    }

    private func buildPickerMenu() -> NSMenu {
        let root = NSMenu()
        let existing = Set(Pref.list(Pref.zones))
        let now = Date()

        func makeItem(_ id: String) -> NSMenuItem {
            let tz = TimeZone(identifier: id)
            let suffix = tz.map { " — \(Fmt.utcOffset($0, at: now))" } ?? ""
            let item = NSMenuItem(title: id + suffix, action: #selector(addZone(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = id
            item.state = existing.contains(id) ? .on : .off
            item.isEnabled = !existing.contains(id)
            return item
        }

        let common = NSMenuItem(title: "Common", action: nil, keyEquivalent: "")
        let commonMenu = NSMenu()
        for id in commonZones { commonMenu.addItem(makeItem(id)) }
        common.submenu = commonMenu
        root.addItem(common)
        root.addItem(.separator())

        let grouped = Dictionary(grouping: TimeZone.knownTimeZoneIdentifiers.filter { $0.contains("/") }) {
            String($0.split(separator: "/")[0])
        }
        for region in grouped.keys.sorted() {
            let item = NSMenuItem(title: region, action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for id in (grouped[region] ?? []).sorted() { sub.addItem(makeItem(id)) }
            item.submenu = sub
            root.addItem(item)
        }
        return root
    }

    private func buildDisplayMenu() -> NSMenu {
        let root = NSMenu()
        let options: [(String, String)] = [
            ("24-Hour Clock", Pref.use24Hour),
            ("Show Seconds", Pref.showSeconds),
            ("Show Date", Pref.showDate),
        ]
        for (title, key) in options {
            let item = NSMenuItem(title: title, action: #selector(togglePref(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = key
            item.state = Pref.flag(key) ? .on : .off
            root.addItem(item)
        }
        root.addItem(.separator())
        for (title, key) in [("Local Time", Pref.showLocal), ("UTC", Pref.showUTC)] {
            let item = NSMenuItem(title: title, action: #selector(togglePref(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = key
            item.state = Pref.flag(key) ? .on : .off
            root.addItem(item)
        }
        return root
    }

    // MARK: Actions

    @objc private func togglePref(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        Pref.toggle(key)
        lastBarTitle = ""
        renderBar()
    }

    @objc private func addZone(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        var zones = Pref.list(Pref.zones)
        guard !zones.contains(id) else { return }
        zones.append(id)
        Pref.setList(Pref.zones, zones)
    }

    @objc private func removeZone(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        Pref.setList(Pref.zones, Pref.list(Pref.zones).filter { $0 != id })
        Pref.setList(Pref.pinned, Pref.list(Pref.pinned).filter { $0 != id })
        lastBarTitle = ""
        renderBar()
    }

    @objc private func togglePin(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        var pinned = Pref.list(Pref.pinned)
        if let idx = pinned.firstIndex(of: id) { pinned.remove(at: idx) } else { pinned.append(id) }
        Pref.setList(Pref.pinned, pinned)
        lastBarTitle = ""
        renderBar()
    }

    @objc private func copyZoneTime(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let tz = TimeZone(identifier: id) else { return }
        let text = Fmt.formatter("yyyy-MM-dd HH:mm:ss", tz).string(from: Date()) + " " + Fmt.tag(for: tz)
        copy(text)
    }

    @objc private func copyISO(_ sender: NSMenuItem) {
        copy(Fmt.formatter("yyyy-MM-dd'T'HH:mm:ss'Z'", TimeZone(identifier: "UTC")!).string(from: Date()))
    }

    @objc private func copyEpoch(_ sender: NSMenuItem) {
        copy(String(Int(Date().timeIntervalSince1970)))
    }

    private func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change the login item"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = ZuluApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
