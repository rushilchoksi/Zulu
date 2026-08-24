import SwiftUI
import ServiceManagement

/// Display toggles, menu bar composition, and app-level actions.
struct SettingsPane: View {

    @EnvironmentObject private var prefs: Preferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            group("Clock") {
                toggle("24-hour clock", isOn: $prefs.use24Hour)
                toggle("Show seconds", isOn: $prefs.showSeconds)
            }

            group("Menu bar") {
                toggle("Local time", isOn: $prefs.showLocal)
                toggle("UTC", isOn: $prefs.showUTC)
                toggle("Date", isOn: $prefs.showDate)
            }

            group("General") {
                toggle("Start at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { _ in toggleLogin() }
                ))

                if let loginError {
                    Text(loginError)
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider().opacity(0.5)

            HStack {
                Button("Quit Zulu") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Zulu 1.1")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionLabel(text: title)
            content()
        }
    }

    /// Label left, switch flush right, so every switch lands in one column
    /// regardless of how long the label is.
    private func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
    }

    private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
