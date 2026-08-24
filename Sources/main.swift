import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let prefs = Preferences()
    private let clock = Clock()
    private var cancellables = Set<AnyCancellable>()
    private var lastTitle = ""
    private let barFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.alignment = .left
        }

        let root = RootView()
            .environmentObject(prefs)
            .environmentObject(clock)
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        clock.$now
            .sink { [weak self] date in self?.renderTitle(at: date) }
            .store(in: &cancellables)

        prefs.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.forceRenderTitle() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSSystemTimeZoneDidChange,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.forceRenderTitle()
        }

        updateLength()
        renderTitle(at: Date())
    }

    // MARK: Menu bar title

    private func forceRenderTitle() {
        lastTitle = ""
        updateLength()
        renderTitle(at: Date())
    }

    private func measure(_ string: String) -> CGFloat {
        (string as NSString).size(withAttributes: [.font: barFont]).width
    }

    /// The widest title the current settings can ever produce.
    ///
    /// Digits are monospaced, so they never change width, but weekday and month
    /// names do, and so does an AM/PM suffix. Left unpinned, the item would
    /// resize every time one of those changed and shove the rest of the menu
    /// bar sideways. Measuring the worst case once and holding that width keeps
    /// the item still.
    private func stableWidth() -> CGFloat {
        let clock = "88:88" + (prefs.showSeconds ? ":88" : "")
        let suffixes = prefs.use24Hour ? [""] : [" AM", " PM"]

        let bodies = suffixes.map { suffix in
            prefs.barZoneIdentifiers
                .compactMap { TimeZone(identifier: $0) }
                .map { "\(TimeKit.tag(for: $0)) \(clock)\(suffix)" }
                .joined(separator: "  ·  ")
        }

        var widest: CGFloat = 0
        if prefs.showDate {
            let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            for body in bodies {
                for weekday in weekdays {
                    for month in months {
                        widest = max(widest, measure("\(weekday) 88 \(month)  " + body))
                    }
                }
            }
        } else {
            for body in bodies { widest = max(widest, measure(body)) }
        }
        return ceil(widest) + 12
    }

    private func updateLength() {
        statusItem.length = stableWidth()
    }

    private func renderTitle(at date: Date) {
        let segments = prefs.barZoneIdentifiers.compactMap { identifier -> String? in
            guard let zone = TimeZone(identifier: identifier) else { return nil }
            let time = TimeKit.time(date, zone, h24: prefs.use24Hour, seconds: prefs.showSeconds)
            let meridiem = prefs.use24Hour ? "" : " " + TimeKit.meridiem(date, zone, h24: false)
            return "\(TimeKit.tag(for: zone)) \(time)\(meridiem)"
        }
        var title = segments.joined(separator: "  ·  ")
        if prefs.showDate {
            title = TimeKit.string(date, .current, "EEE d MMM") + "  " + title
        }

        guard title != lastTitle else { return }
        lastTitle = title
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        statusItem.button?.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: barFont, .paragraphStyle: paragraph])
    }

    // MARK: Interaction

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let quit = NSMenuItem(title: "Quit Zulu",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    /// Leaving the panel scrubbed would be a trap: snap back to now on close.
    func popoverDidClose(_ notification: Notification) {
        clock.resetScrub()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
