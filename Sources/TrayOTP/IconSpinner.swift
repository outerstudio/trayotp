import AppKit

/// Turns the ring of the icon now and then, as a small surprise. The menu bar icon, the lock
/// screen and dialog icons (`NSApp.applicationIconImage`) all follow `rotation`. The icon in
/// Finder and Launchpad can't follow: it is the signed bundle's AppIcon.icns.
///
/// It turns when the app locks (sometimes), at a random moment every few hours, and on the lock
/// screen, where the ring counts down like a code and may turn when it refills (see `LockIcon`).
/// Turns always go clockwise, to anywhere at least a sixth of a turn away. With Reduce Motion
/// the ring jumps instead of turning.
@MainActor
@Observable
final class IconSpinner {
    /// Degrees clockwise from the shipped icon (gap at 10:30), as shown right now.
    private(set) var rotation: Double

    @ObservationIgnored private var animation: Timer?
    @ObservationIgnored private var wander: Timer?

    private static let key = "iconRotation"
    /// How long a turn takes; the lock screen's ring refills in the same time.
    nonisolated static let duration: TimeInterval = 0.9

    static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    init() {
        rotation = UserDefaults.standard.double(forKey: Self.key)
        updateAppIcon()
        scheduleWander()
    }

    /// Turns with probability `chance` (0…1).
    func maybeTurn(chance: Double) {
        if Double.random(in: 0..<1) < chance { turn() }
    }

    func turn() {
        guard animation == nil else { return }
        let from = rotation, to = from + Double.random(in: 60...300)
        guard !Self.reduceMotion else { return finish(at: to) }

        let start = Date()
        animation = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let t = min(Date().timeIntervalSince(start) / Self.duration, 1)
                self.rotation = from + (to - from) * Self.ease(t)
                if t >= 1 { self.finish(at: to) }
            }
        }
    }

    /// Ease in and out (0…1), so the ring winds up and settles like a dial.
    static func ease(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    private func finish(at angle: Double) {
        animation?.invalidate()
        animation = nil
        rotation = angle.truncatingRemainder(dividingBy: 360)
        UserDefaults.standard.set(rotation, forKey: Self.key)
        updateAppIcon()
    }

    /// Dialogs (NSAlert) show the app icon; keep them in step. Not per animation frame.
    private func updateAppIcon() {
        NSApplication.shared.applicationIconImage = IconArt.appIcon(rotation: rotation)
    }

    /// A turn at a random moment one to six hours from now, then the next one.
    private func scheduleWander() {
        wander?.invalidate()
        wander = Timer.scheduledTimer(withTimeInterval: .random(in: 3600...6 * 3600), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.turn()
                self?.scheduleWander()
            }
        }
    }
}
