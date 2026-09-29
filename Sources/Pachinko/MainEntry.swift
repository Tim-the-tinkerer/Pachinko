import AppKit
import SwiftUI

@main
struct MainEntry {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    /// True while a Settings choice is animating, so the system notification does not overwrite it.
    private var windowModeApplyInFlight = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()

        let rootView = ContentView()
            .preferredColorScheme(.dark)
        let hosting = NSHostingView(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 1000),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pachinko"
        window.contentView = hosting
        window.minSize = NSSize(width: 560, height: 760)
        window.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]
        window.center()
        window.setFrameAutosaveName("PachinkoMainWindow")
        window.isReleasedWhenClosed = false
        window.backgroundColor = DisplaySettings.shared.palette.voidNS
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applySavedWindowMode),
            name: .pachinkoApplyWindowMode,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidEnterFullScreen(_:)),
            name: NSWindow.didEnterFullScreenNotification,
            object: window
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidExitFullScreen(_:)),
            name: NSWindow.didExitFullScreenNotification,
            object: window
        )
        if DisplaySettings.shared.windowMode == .fullScreen {
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window else { return }
                guard !window.styleMask.contains(.fullScreen) else { return }
                self.windowModeApplyInFlight = true
                window.toggleFullScreen(nil)
            }
        }

        Task { @MainActor in
            GameSound.shared.setMusicContext(menu: true, fever: false, theme: DisplaySettings.shared.cabinetTheme)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "About Pachinko",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide Pachinko", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(
            withTitle: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Pachinko", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let gameMenuItem = NSMenuItem()
        mainMenu.addItem(gameMenuItem)
        let gameMenu = NSMenu(title: "Game")
        gameMenuItem.submenu = gameMenu
        let soundItem = gameMenu.addItem(
            withTitle: "Toggle Sound Effects",
            action: #selector(toggleSound(_:)),
            keyEquivalent: "m"
        )
        soundItem.keyEquivalentModifierMask = [.command, .shift]
        soundItem.target = self
        let musicItem = gameMenu.addItem(
            withTitle: "Toggle Music",
            action: #selector(toggleMusic(_:)),
            keyEquivalent: ""
        )
        musicItem.target = self

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        viewMenu.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        viewMenu.addItem(NSMenuItem.separator())
        let themeItem = viewMenu.addItem(
            withTitle: "Cycle Cabinet",
            action: #selector(cycleTheme(_:)),
            keyEquivalent: ""
        )
        themeItem.target = self
        let crtItem = viewMenu.addItem(
            withTitle: "Toggle CRT Effect",
            action: #selector(toggleCRT(_:)),
            keyEquivalent: ""
        )
        crtItem.target = self

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu

        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "Help")
        helpMenuItem.submenu = helpMenu
        helpMenu.addItem(withTitle: "Pachinko Help", action: #selector(showHelp(_:)), keyEquivalent: "?")
        helpMenu.items.last?.target = self
        NSApp.helpMenu = helpMenu

        NSApp.mainMenu = mainMenu
    }

    @MainActor
    @objc private func applySavedWindowMode() {
        guard let window else { return }
        let wantsFull = DisplaySettings.shared.windowMode == .fullScreen
        let isFull = window.styleMask.contains(.fullScreen)
        guard wantsFull != isFull else { return }
        windowModeApplyInFlight = true
        window.toggleFullScreen(nil)
    }

    @MainActor
    @objc private func windowDidEnterFullScreen(_ notification: Notification) {
        reconcileWindowMode(isFull: true)
    }

    @MainActor
    @objc private func windowDidExitFullScreen(_ notification: Notification) {
        reconcileWindowMode(isFull: false)
    }

    @MainActor
    private func reconcileWindowMode(isFull: Bool) {
        if windowModeApplyInFlight {
            windowModeApplyInFlight = false
            let wantsFull = DisplaySettings.shared.windowMode == .fullScreen
            if wantsFull != isFull {
                windowModeApplyInFlight = true
                window?.toggleFullScreen(nil)
            }
            return
        }
        let mode: WindowMode = isFull ? .fullScreen : .window
        if DisplaySettings.shared.windowMode != mode {
            DisplaySettings.shared.windowMode = mode
        }
    }

    @objc private func toggleSound(_ sender: Any?) {
        Task { @MainActor in GameSound.shared.toggle() }
    }

    @objc private func toggleMusic(_ sender: Any?) {
        Task { @MainActor in DisplaySettings.shared.toggleMusic() }
    }

    @objc private func cycleTheme(_ sender: Any?) {
        Task { @MainActor in
            DisplaySettings.shared.cycleCabinet()
            self.window?.backgroundColor = DisplaySettings.shared.palette.voidNS
        }
    }

    @objc private func toggleCRT(_ sender: Any?) {
        Task { @MainActor in DisplaySettings.shared.toggleCRT() }
    }

    @objc private func showHelp(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Pachinko 1.0.13"
        alert.informativeText = """
        A Japanese parlor machine. Crank the handle, rain steel balls through the nails, and aim for the start hole.

        Hold Space or click the board to fire. ← → / A D set handle power. On the classic boards, the middle of the handle drops over the start hole. Lantern Alley keeps that hole to the right.

        START hole spins the digital reels. 7-7-7 starts FEVER: the attacker gate opens in rounds and pays a pile of balls. Side tulips pay a couple back. Miss the board and the ball is gone. Ordinary play spends the tray. Fever fills it again.

        Settings, on the main screen, holds the screen mode, difficulty, CRT glass, music, sound effects, and cabinet wear.
        Window keeps Pachinko in a resizable window. Full screen fills the display. Command-F switches too, and the choice is remembered.

        Cabinet wear marks the frame the more you play a machine, and the wheel drifts a little. Dragon and Koi slow down. Neon, Lantern, and River speed up. Sakura's wheel stays put. Settings can turn wear off or reset every cabinet.
        T — cycle cabinet (six boards: classic, garden, alley, river)
        C — CRT glass  ·  M — music
        P — pause  ·  Esc — menu, or leave Settings
        1 / 2 / 3 — Novice / Arcade / Insane

        Arcade entertainment — no cash, just the tray.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
