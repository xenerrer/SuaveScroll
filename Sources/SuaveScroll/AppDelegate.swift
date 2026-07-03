import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    private let engine = ScrollEngine()
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(engine: engine)
        UpdateChecker.shared.startPeriodicChecks()
        DiagLog.write("launched — accessibility granted: \(AccessibilityPermission.isGranted)")

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
