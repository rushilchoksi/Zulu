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

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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

        renderTitle(at: Date())
    }

    // MARK: Menu bar title

    private func forceRenderTitle() {
        lastTitle = ""
        renderTitle(at: Date())
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
        statusItem.button?.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)])
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
