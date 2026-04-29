import AppKit
import SwiftUI

enum SettingsWindowPresenter {
    static let windowIdentifier = NSUserInterfaceItemIdentifier("agent-battery.settings")

    static func show(openSettings: () -> Void) {
        if focusExistingWindow() {
            return
        }

        openSettings()
        focusWhenWindowIsReady()
    }

    @discardableResult
    static func focusExistingWindow() -> Bool {
        guard let window = settingsWindow else {
            return false
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        return true
    }

    private static var settingsWindow: NSWindow? {
        NSApplication.shared.windows.first { window in
            window.identifier == windowIdentifier
        }
    }

    private static func focusWhenWindowIsReady() {
        DispatchQueue.main.async {
            _ = focusExistingWindow()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            _ = focusExistingWindow()
        }
    }
}

struct SettingsWindowIdentifierView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            identifyWindow(for: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            identifyWindow(for: nsView)
        }
    }

    private func identifyWindow(for view: NSView) {
        guard let window = view.window else {
            return
        }

        window.identifier = SettingsWindowPresenter.windowIdentifier
    }
}
