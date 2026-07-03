import AppKit
import ServiceManagement
import SwiftUI

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let engine: ScrollEngine
    private var settingsWindow: NSWindow?

    private var enabledItem: NSMenuItem!
    private var accessibilityItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var updateItem: NSMenuItem!

    init(engine: ScrollEngine) {
        self.engine = engine
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "SuaveScroll") {
                button.image = image
            } else {
                button.title = "SS"
            }
        }
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        accessibilityItem = NSMenuItem(
            title: "Conceder Acesso de Acessibilidade…",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        updateItem = NSMenuItem(title: "Baixar Atualização…", action: #selector(openDownloadPage), keyEquivalent: "")
        updateItem.target = self
        updateItem.isHidden = true
        menu.addItem(updateItem)

        enabledItem = NSMenuItem(title: "Rolagem Suave", action: #selector(toggleEnabled), keyEquivalent: "e")
        enabledItem.target = self
        menu.addItem(enabledItem)

        let settingsItem = NSMenuItem(title: "Configurações…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        loginItem = NSMenuItem(title: "Iniciar com o Mac", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let githubItem = NSMenuItem(title: "GitHub (@lucasschoenherr)…", action: #selector(openGitHub), keyEquivalent: "")
        githubItem.target = self
        menu.addItem(githubItem)

        let aboutItem = NSMenuItem(title: "Sobre o SuaveScroll", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Encerrar SuaveScroll", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let granted = AccessibilityPermission.isGranted
        accessibilityItem.isHidden = granted

        if UpdateChecker.shared.updateAvailable, let latest = UpdateChecker.shared.latestVersion {
            updateItem.title = "⬆️ Atualizar para a versão \(latest)…"
            updateItem.isHidden = false
        } else {
            updateItem.isHidden = true
        }
        enabledItem.isEnabled = granted
        enabledItem.state = (granted && Settings.shared.isEnabled) ? .on : .off

        // Launch-at-login needs a real .app bundle; hide it when running the
        // bare executable via `swift run`.
        let bundled = Bundle.main.bundleIdentifier != nil
        loginItem.isHidden = !bundled
        if bundled {
            loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }

    @objc private func toggleEnabled() {
        Settings.shared.isEnabled.toggle()
        if !Settings.shared.isEnabled {
            engine.flushAnimation()
        }
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityPermission.openSystemSettings()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSLog("SuaveScroll: launch-at-login change failed: \(error)")
        }
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/xenerrer/SuaveScroll")!)
    }

    @objc private func openDownloadPage() {
        NSWorkspace.shared.open(UpdateChecker.downloadPageURL)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(model: SettingsModel()))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Configurações do SuaveScroll"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
