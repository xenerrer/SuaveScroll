import AppKit
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    private let engine = ScrollEngine()
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(engine: engine)
        UpdateChecker.shared.startPeriodicChecks()
        DiagLog.write("launched — accessibility granted: \(AccessibilityPermission.isGranted)")
        enableLaunchAtLoginOnFirstRun()
        observeWakeFromSleep()

        if AccessibilityPermission.isGranted {
            engine.start()
        } else {
            AccessibilityPermission.prompt()
            // Poll until the user grants access in System Settings, then start.
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
                guard let self, AccessibilityPermission.isGranted else { return }
                timer.invalidate()
                self.permissionTimer = nil
                DiagLog.write("accessibility granted, starting engine")
                self.engine.start()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
    }

    /// Registers the app as a login item on first run so smoothing survives a
    /// reboot without any setup. The "Iniciar com o Mac" menu item can undo it.
    private func enableLaunchAtLoginOnFirstRun() {
        let key = "didSetupLaunchAtLogin"
        guard Bundle.main.bundleIdentifier != nil,
              !UserDefaults.standard.bool(forKey: key) else { return }
        do {
            try SMAppService.mainApp.register()
            // Only remember success — a failed first attempt (e.g. app still
            // quarantined in ~/Downloads) should retry on the next launch.
            UserDefaults.standard.set(true, forKey: key)
            DiagLog.write("iniciar com o Mac ativado automaticamente (primeira execução)")
        } catch {
            DiagLog.write("falha ao ativar iniciar com o Mac: \(error)")
        }
    }

    /// macOS can silently disable event taps around sleep/wake (timeout,
    /// secure input). Re-check the tap every time the machine wakes up.
    private func observeWakeFromSleep() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, AccessibilityPermission.isGranted else { return }
            DiagLog.write("acordou do repouso — verificando event tap")
            self.engine.ensureRunning()
        }
    }
}

enum AccessibilityPermission {
    static var isGranted: Bool { AXIsProcessTrusted() }

    static func prompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
