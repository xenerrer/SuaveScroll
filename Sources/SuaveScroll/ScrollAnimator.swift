import CoreGraphics
import Foundation

/// Turns accumulated wheel impulses into a stream of smooth pixel scroll events.
///
/// Runs a 120 Hz timer on a dedicated high-priority queue. Each frame emits a
/// fixed fraction of the remaining distance (exponential ease-out), so fast
/// consecutive wheel ticks naturally accelerate and then glide to a stop.
final class ScrollAnimator {
    /// Marker stamped on every synthesized event so the tap can recognize and
    /// ignore them instead of re-smoothing (which would loop forever).
    static let syntheticEventMarker: Int64 = 0x5356_5343_524F_4C21

    private let queue = DispatchQueue(label: "com.lucasschoenherr.suavescroll.animator", qos: .userInteractive)
    private let frameInterval = 1.0 / 120.0
    private let maxPending: Double = 8000

    private var timer: DispatchSourceTimer?
    private var pendingX: Double = 0
    private var pendingY: Double = 0
    private var currentFlags = CGEventFlags(rawValue: 0)
    private let eventSource: CGEventSource?

    init() {
        eventSource = CGEventSource(stateID: .hidSystemState)
        eventSource?.userData = Self.syntheticEventMarker
        // The default 0.25 s suppression interval would block real hardware
        // input after every synthetic post — at 120 Hz that freezes the mouse
        // for the whole glide.
        eventSource?.localEventsSuppressionInterval = 0
    }

    /// Adds a scroll impulse (in pixels). Called from the event tap thread.
    func add(dx: Double, dy: Double, flags: CGEventFlags) {
        queue.async { [self] in
            pendingX = clamp(pendingX + dx)
            pendingY = clamp(pendingY + dy)
            currentFlags = flags
            startTimerIfNeeded()
        }
    }

    /// Discards any distance still to be scrolled.
    func cancel() {
        queue.async { [self] in
            pendingX = 0
            pendingY = 0
            stopTimer()
        }
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, -maxPending), maxPending)
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + frameInterval, repeating: frameInterval, leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        if abs(pendingX) < 0.5 { pendingX = 0 }
        if abs(pendingY) < 0.5 { pendingY = 0 }
        if pendingX == 0 && pendingY == 0 {
            stopTimer()
            return
        }

        // Fraction of the remaining distance emitted this frame, derived from
        // the configured glide duration (time to settle ~99% of the distance).
        let duration = max(Settings.shared.durationMs, 50) / 1000.0
        let k = 1.0 - pow(0.01, frameInterval / duration)

        var ix = Int32((pendingX * k).rounded(.toNearestOrAwayFromZero))
        var iy = Int32((pendingY * k).rounded(.toNearestOrAwayFromZero))

        // Guarantee forward progress so the tail can't stall below 1 px/frame.
        if ix == 0 && iy == 0 {
            if abs(pendingY) >= abs(pendingX) {
                iy = pendingY > 0 ? 1 : -1
            } else {
                ix = pendingX > 0 ? 1 : -1
            }
        }

        pendingX -= Double(ix)
        pendingY -= Double(iy)
        post(ix: ix, iy: iy)
    }

    private func post(ix: Int32, iy: Int32) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: eventSource,
            units: .pixel,
            wheelCount: 2,
            wheel1: iy,
            wheel2: ix,
            wheel3: 0
        ) else { return }

        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
        // Preserve modifiers (e.g. Ctrl+scroll zoom) held on the original event.
        event.flags = currentFlags
        // Route the event to the window currently under the pointer.
        if let reference = CGEvent(source: nil) {
            event.location = reference.location
        }
        event.post(tap: .cghidEventTap)
    }
}
