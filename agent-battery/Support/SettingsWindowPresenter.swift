import AppKit
import SwiftUI

@MainActor
enum SettingsWindowPresenter {
    static let windowIdentifier = NSUserInterfaceItemIdentifier("agent-battery.settings")
    private static var focusRequestID = 0

    static func show(dismissingMenuBarPanel dismissMenuBarPanel: @escaping () -> Void, openSettings: @escaping () -> Void) {
        focusRequestID += 1
        let requestID = focusRequestID

        dismissMenuBarPanel()

        scheduleFocus(after: 0.08, requestID: requestID) {
            NSApplication.shared.activate(ignoringOtherApps: true)

            if focusExistingWindow() {
                return
            }

            openSettings()
            focusWhenWindowIsReady(requestID: requestID)
        }
    }

    @discardableResult
    static func focusExistingWindow() -> Bool {
        guard let window = settingsWindow else {
            return false
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        return true
    }

    private static var settingsWindow: NSWindow? {
        NSApplication.shared.windows.first { window in
            window.identifier == windowIdentifier
        }
    }

    private static func focusWhenWindowIsReady(requestID: Int) {
        retryFocus(attemptsRemaining: 30, requestID: requestID)
    }

    private static func retryFocus(attemptsRemaining: Int, requestID: Int) {
        guard requestID == focusRequestID else {
            return
        }

        if focusExistingWindow() || attemptsRemaining <= 0 {
            return
        }

        scheduleFocus(after: 0.05, requestID: requestID) {
            retryFocus(attemptsRemaining: attemptsRemaining - 1, requestID: requestID)
        }
    }

    private static func scheduleFocus(after delay: TimeInterval, requestID: Int, _ action: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            Task { @MainActor in
                guard requestID == focusRequestID else {
                    return
                }
                action()
            }
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
        SettingsWindowPresenter.attachColorPanelAutoClose(to: window)
    }
}

extension SettingsWindowPresenter {
    private static var observedWindows = NSHashTable<NSWindow>.weakObjects()

    static func attachColorPanelAutoClose(to window: NSWindow) {
        guard !observedWindows.contains(window) else { return }
        observedWindows.add(window)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            let panel = NSColorPanel.shared
            if panel.isVisible {
                panel.close()
            }
        }
    }
}
