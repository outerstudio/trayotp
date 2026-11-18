import Foundation

/// How much of the menu bar icon's ring is lit. While it follows the codes it counts down like the
/// progress behind each row and sweeps full again when they change; otherwise it rests at three
/// quarters, as in the app icon.
///
/// TOTP codes change on whole multiples of their period since 1970, so one clock fits every token
/// with that period. To spare the battery it wakes only when the ring visibly moves: one 3° step,
/// about four times a second for 30-second codes, and smoothly only during the short refill. Each
/// wake-up has a tolerance, so macOS can group it with others.
@MainActor
@Observable
final class MenuBarRing {
    /// 0…1, from where the ring starts, clockwise.
    private(set) var remaining: Double = MenuBarRing.resting

    static let resting = 0.75
    /// Steps per period while draining: 120 is 3° of the ring, finer than an 18 pt icon shows.
    private static let steps = 120.0

    @ObservationIgnored private var period: TimeInterval?
    @ObservationIgnored private var end: Date?
    @ObservationIgnored private var timer: Timer?

    /// Counts down with codes of `period` seconds until `end` (nil: until told otherwise), or
    /// rests when `period` is nil.
    func follow(period: TimeInterval?, until end: Date?) {
        self.period = period
        self.end = end
        tick()
    }

    private func tick() {
        timer?.invalidate()
        timer = nil
        let now = Date()
        guard let period, end.map({ now < $0 }) ?? true else {
            remaining = Self.resting
            return
        }
        let phase = now.timeIntervalSince1970.truncatingRemainder(dividingBy: period)
        let refill = min(IconSpinner.duration, period / 4)
        var wait: TimeInterval
        if phase < refill {
            if IconSpinner.reduceMotion {
                // No sweep: full until the drain starts.
                remaining = 1
                wait = refill - phase
            } else {
                remaining = IconSpinner.ease(phase / refill)
                wait = 1.0 / 30
            }
        } else {
            let drained = (phase - refill) / (period - refill)
            // Round down to a whole step, and wake at the next one (or when the codes change).
            let step = (drained * Self.steps).rounded(.down) / Self.steps
            remaining = 1 - step
            wait = min((step + 1 / Self.steps - drained) * (period - refill), period - phase)
        }
        if let end { wait = min(wait, end.timeIntervalSince(now)) }

        let timer = Timer(timeInterval: max(wait, 0.01), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = min(wait * 0.1, 0.05)
        // .common: keep ticking while a menu is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}

/// When the menu bar icon's ring stops counting down with the codes.
enum MenuBarCountdown: String, CaseIterable {
    /// Never: the ring rests.
    case off
    /// Until Stay Unlocked runs out after the panel closes, or the vault locks.
    case untilGraceEnds
    /// Until the vault locks (Lock, sleep, screen lock, or the next open after Stay Unlocked).
    case untilLocked
}
