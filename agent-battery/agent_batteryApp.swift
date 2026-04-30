import SwiftUI

@main
struct AgentBatteryApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var store: UsageStore

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: UsageStore(settings: settings))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanelView(settings: settings, store: store)
                .frame(width: 340)
                .onAppear {
                    store.refresh()
                }
        } label: {
            MenuBarLabelView(settings: settings, store: store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings)
        }
    }
}
