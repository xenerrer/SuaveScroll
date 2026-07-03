import Foundation

/// UserDefaults-backed app settings. UserDefaults is thread-safe, so these
/// accessors may be read from the event tap (main thread) and the animator queue.
final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    enum Key {
        static let enabled = "enabled"
        static let stepSize = "stepSize"
        static let durationMs = "durationMs"
        static let reverseDirection = "reverseDirection"
        static let excludedBundleIds = "excludedBundleIds"
    }

    private init() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.stepSize: 60.0,
            Key.durationMs: 240.0,
            Key.reverseDirection: false,
            Key.excludedBundleIds: [String]()
        ])
    }

    /// Master switch for smoothing.
    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    /// Pixels scrolled per wheel tick (before system acceleration).
    var stepSize: Double {
        get { defaults.double(forKey: Key.stepSize) }
        set { defaults.set(newValue, forKey: Key.stepSize) }
    }

    /// Approximate time, in milliseconds, for a glide to settle (~99% of the distance).
    var durationMs: Double {
        get { defaults.double(forKey: Key.durationMs) }
        set { defaults.set(newValue, forKey: Key.durationMs) }
    }

    var reverseDirection: Bool {
        get { defaults.bool(forKey: Key.reverseDirection) }
        set { defaults.set(newValue, forKey: Key.reverseDirection) }
    }

    /// Bundle identifiers of apps whose scrolling is left untouched.
    var excludedBundleIds: [String] {
        get { defaults.stringArray(forKey: Key.excludedBundleIds) ?? [] }
        set { defaults.set(newValue, forKey: Key.excludedBundleIds) }
    }
}
