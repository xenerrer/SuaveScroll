import AppKit
import CoreGraphics

/// Intercepts discrete mouse-wheel events system-wide and replaces them with
/// smooth, pixel-based scrolling driven by `ScrollAnimator`.
///
/// Continuous devices (trackpads, Magic Mouse) already scroll smoothly and are
/// passed through untouched, as are our own synthesized events.
final class ScrollEngine {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapThread: Thread?
    private var tapRunLoop: CFRunLoop?
    private let animator = ScrollAnimator()
    // Logs the shape of the first incoming wheel events so users can diagnose
    // why smoothing isn't kicking in (e.g. a driver already emits continuous
    // events). Only touched on the tap thread.
    private var diagnosticsRemaining = 15

    var isRunning: Bool { eventTap != nil }

    func start() {
        guard eventTap == nil else { return }

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let engine = Unmanaged<ScrollEngine>.fromOpaque(userInfo).takeUnretainedValue()
                return engine.handle(type: type, event: event)
            },
            userInfo: userInfo
        ) else {
            DiagLog.write("could not create event tap — is Accessibility access granted?")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source

        // Service the tap on a dedicated thread so a busy main thread (menus,
        // settings UI) can never delay system-wide scrolling.
        let thread = Thread { [weak self] in
            self?.tapRunLoop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            DiagLog.write("event tap active")
            CFRunLoopRun()
        }
        thread.name = "com.lucasschoenherr.suavescroll.eventTap"
        thread.qualityOfService = .userInteractive
        thread.start()
        tapThread = thread
    }

    func stop() {
        animator.cancel()
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoop = tapRunLoop {
            if let source = runLoopSource {
                CFRunLoopRemoveSource(runLoop, source, .commonModes)
            }
            CFRunLoopStop(runLoop)
        }
        tapRunLoop = nil
        runLoopSource = nil
        eventTap = nil
        tapThread = nil
    }

    /// Drops any in-flight glide (used when the user disables smoothing).
    func flushAnimation() {
        animator.cancel()
    }

    /// Revives the tap if the system disabled it (e.g. across sleep/wake).
    /// Safe to call repeatedly; must run on the main thread.
    func ensureRunning() {
        if let tap = eventTap {
            if !CGEvent.tapIsEnabled(tap: tap) {
                CGEvent.tapEnable(tap: tap, enable: true)
                DiagLog.write("event tap religado")
            }
        } else {
            start()
        }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system disables taps that are slow or when secure input kicks in.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .scrollWheel else {
            return Unmanaged.passUnretained(event)
        }

        // Our own synthesized events come back through the tap — let them pass.
        if event.getIntegerValueField(.eventSourceUserData) == ScrollAnimator.syntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        if diagnosticsRemaining > 0 {
            diagnosticsRemaining -= 1
            let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)
            let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
            let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
            let fixedY = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
            let fixedX = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
            let lineY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            let pid = event.getIntegerValueField(.eventTargetUnixProcessID)
            DiagLog.write("wheel event — continuous=\(continuous) phase=\(phase) momentum=\(momentum) fixedY=\(fixedY) fixedX=\(fixedX) lineY=\(lineY) pid=\(pid)")
        }

        guard Settings.shared.isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        // Trackpads and Magic Mice scroll through the gesture system and
        // always carry phase information — those are already smooth and must
        // never be re-synthesized. Anything phaseless is wheel input, even
        // when a vendor driver (e.g. Logi Options+) has already upgraded it
        // to "continuous" pixel events.
        if event.getIntegerValueField(.scrollWheelEventScrollPhase) != 0 ||
            event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0 {
            return Unmanaged.passUnretained(event)
        }
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0

        if let bundleId = targetBundleId(of: event),
           Settings.shared.excludedBundleIds.contains(bundleId) {
            return Unmanaged.passUnretained(event)
        }

        // Fixed-point deltas preserve fractional wheel input; fall back to the
        // integer line deltas if a driver only fills those in.
        var dy = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        var dx = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
        if dy == 0 { dy = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1)) }
        if dx == 0 { dx = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2)) }
        if dy == 0 && dx == 0 {
            return Unmanaged.passUnretained(event)
        }

        if Settings.shared.reverseDirection {
            dy = -dy
            dx = -dx
        }

        // Shift + wheel scrolls horizontally. The shift flag is dropped from the
        // synthesized event so target apps don't swap the axis a second time.
        var flags = event.flags
        if flags.contains(.maskShift), dx == 0, dy != 0 {
            swap(&dx, &dy)
            flags.remove(.maskShift)
        }

        // Discrete events measure lines per wheel tick; continuous events
        // measure pixels (~20 px per notch). Scale both so `stepSize` always
        // means "pixels per notch" regardless of the driver in front of us.
        let step = isContinuous ? Settings.shared.stepSize / 20.0 : Settings.shared.stepSize
        animator.add(dx: dx * step, dy: dy * step, flags: flags)

        // Swallow the discrete event; the animator re-emits it smoothly.
        return nil
    }

    private func targetBundleId(of event: CGEvent) -> String? {
        let pid = pid_t(event.getIntegerValueField(.eventTargetUnixProcessID))
        if pid > 0, let bundleId = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier {
            return bundleId
        }
        // The target pid isn't always populated at head-insert taps; assume
        // the user is scrolling the frontmost app.
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
