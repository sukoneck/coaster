import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    private let priceModel = PriceModel()
    private var settingsWindow: NSWindow?

    private var popoverWidth: CGFloat = 300
    private var lastPopoverHeight: CGFloat = 220

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: "NOCK")
                ?? NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "NOCK")
            img?.isTemplate = true
            button.image = img
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: popoverWidth, height: lastPopoverHeight)
        popover.contentViewController = NSHostingController(
            rootView: PriceView()
                .environmentObject(priceModel)
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettingsWindow),
            name: .openSettingsWindow,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resizePopover(_:)),
            name: .resizePopover,
            object: nil
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Downward only
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // Fetch after the popover is on-screen to reduce layout weirdness.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self, self.popover.isShown else { return }
                Task { await self.priceModel.fetch() }
            }
        }
    }

    @objc private func resizePopover(_ note: Notification) {
        guard let heightDouble = note.userInfo?["height"] as? Double else { return }
        let newHeight = CGFloat(heightDouble)

        // Don’t churn size changes.
        if abs(newHeight - lastPopoverHeight) < 1 { return }
        lastPopoverHeight = newHeight

        // If it's not shown yet, just update the stored size.
        guard popover.isShown else {
            popover.contentSize = NSSize(width: popoverWidth, height: lastPopoverHeight)
            return
        }

        // Resize on next tick to avoid layout recursion.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.popover.isShown else { return }
            self.popover.contentSize = NSSize(width: self.popoverWidth, height: self.lastPopoverHeight)
        }
    }

    @objc private func openSettingsWindow() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: host)
            window.title = "🎢 Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 460, height: 220))
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
