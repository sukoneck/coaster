import Cocoa
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    private let priceModel = PriceModel()
    private let windowState = WindowState()

    private var settingsWindow: NSWindow?
    private var pinnedWindow: NSWindow?

    private var popoverWidth: CGFloat = 236
    private var lastPopoverHeight: CGFloat = 220

    private var cancellables = Set<AnyCancellable>()

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

        popover.delegate = self
        popover.behavior = .transient
        popover.contentSize = NSSize(width: popoverWidth, height: lastPopoverHeight)
        popover.contentViewController = NSHostingController(
            rootView: PriceView(isWindowMode: false)
                .environmentObject(priceModel)
                .environmentObject(windowState)
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettingsWindow),
            name: .openSettingsWindow,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openPinnedWindow),
            name: .openPinnedWindow,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resizePopover(_:)),
            name: .resizePopover,
            object: nil
        )

        windowState.$isAlwaysOnTop
            .removeDuplicates()
            .sink { [weak self] isOnTop in
                guard let self else { return }
                self.applyAlwaysOnTop(isOnTop)
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)

            // Ensure it uses the latest width before showing (in case you tweak it later)
            popover.contentSize = NSSize(width: popoverWidth, height: lastPopoverHeight)

            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self, self.popover.isShown else { return }
                Task { await self.priceModel.fetch() }
            }
        }
    }

    @objc private func appDidResignActive() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    @objc private func resizePopover(_ note: Notification) {
        guard let heightDouble = note.userInfo?["height"] as? Double else { return }
        let newHeight = CGFloat(heightDouble)

        if abs(newHeight - lastPopoverHeight) < 1 { return }
        lastPopoverHeight = newHeight

        guard popover.isShown else {
            popover.contentSize = NSSize(width: popoverWidth, height: lastPopoverHeight)
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.popover.isShown else { return }
            self.popover.contentSize = NSSize(width: self.popoverWidth, height: self.lastPopoverHeight)
        }
    }

    @objc private func openPinnedWindow() {
        if popover.isShown {
            popover.performClose(nil)
        }

        if pinnedWindow == nil {
            let host = NSHostingController(
                rootView: PriceView(isWindowMode: true)
                    .environmentObject(priceModel)
                    .environmentObject(windowState)
            )

            let window = NSWindow(contentViewController: host)
            window.titleVisibility = .hidden

            // Also use the slimmer width for the window if you want it consistent
            window.setContentSize(NSSize(width: popoverWidth, height: lastPopoverHeight))

            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            pinnedWindow = window

            applyAlwaysOnTop(windowState.isAlwaysOnTop)
        }

        pinnedWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        Task { await priceModel.fetch() }
    }

    private func applyAlwaysOnTop(_ isOnTop: Bool) {
        guard let window = pinnedWindow else { return }
        window.level = isOnTop ? .floating : .normal
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
