// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Readings: where a value the host animates has got to, copied into an ordinary
// state at a rate an author chooses.
// Design: docs/design/core/journeys.md#readings


/// One reading of one source into one target, at one rate - held by the element
/// that asked for it, known weakly by the source.
final class Sampling: @unchecked Sendable {
    /// Guards the window: the host writes on the UI thread, and a booked reading
    /// resumes on another.
    private let guarded = Lock()

    /// The earliest moment this reading may be taken again.
    private var next: ContinuousClock.Instant?

    /// Whether a reading is already booked for the end of this window.
    private var waiting = false

    /// The shortest time between readings, in milliseconds; nought is every frame.
    let window: Int

    /// What one reading does, as this render wrote it.
    private var taking: @Sendable () -> Void

    /// Takes the reading. Replaced on every render - the closure holds that render's
    /// bindings - and read under the lock, since a booked reading may be running it.
    var take: @Sendable () -> Void {
        get { guarded.withLock { taking } }
        set { guarded.withLock { taking = newValue } }
    }

    /// A reading at a rate, and what one reading does.
    init(window: Int, take: @escaping @Sendable () -> Void) {
        self.window = window
        self.taking = take
    }

    /// What this frame should do about the reading, with the bookkeeping, under one
    /// hold. `now` is stated so a test can hold the clock.
    func due(at now: ContinuousClock.Instant = .now) -> Due {
        guarded.withLock {
            if waiting { return .waiting }

            guard let next, now < next else {
                self.next = now + .milliseconds(max(0, window))
                return .now
            }

            waiting = true
            return .waitUntil(next)
        }
    }

    /// Records that the booked reading was taken, starting the next window.
    func took(at now: ContinuousClock.Instant = .now) {
        guarded.withLock {
            waiting = false
            next = now + .milliseconds(max(0, window))
        }
    }

    /// What a frame should do about a reading.
    enum Due: Equatable {
        /// Take it now. The window starts again from this moment.
        case now

        /// Take it when this moment comes - nobody is waiting for it yet.
        case waitUntil(ContinuousClock.Instant)

        /// Do nothing: a reading is already booked and will cover this frame
        /// too.
        case waiting
    }
}

/// One reading, as the value it reads knows it: weakly.
final class WeakSampling: @unchecked Sendable {
    weak var sampling: Sampling?

    init(_ sampling: Sampling) { self.sampling = sampling }
}

extension HostStorage {
    /// Asks for a reading of this value into `target`, or hands this render's closure
    /// to the standing one at the same rate, which keeps its window; a changed rate
    /// is a new reading. The element keeps what this answers.
    /// Design: docs/design/core/journeys.md#readings
    func sample(
        into target: ObjectIdentifier,
        every window: Int,
        take: @escaping @Sendable () -> Void
    ) -> Sampling {
        if let standing = samplings[target]?.sampling, standing.window == window {
            standing.take = take
            return standing
        }

        let made = Sampling(window: window, take: take)

        samplings[target] = WeakSampling(made)
        return made
    }

    /// Runs every reading asked for of this value, after the host wrote its lanes; a
    /// reading inside its window books one for the window's end.
    func sampleTaken() {
        for (target, held) in samplings {
            // A reading whose element has gone is swept; the walk is over a copy.
            guard let sampling = held.sampling else {
                samplings[target] = nil
                continue
            }

            switch sampling.due() {
            case .now:
                sampling.take()

            case .waiting:
                break

            case .waitUntil(let deadline):
                // `Task.sleep`, not a run-loop timer (Ticker.swift).
                Task {
                    try? await Task.sleep(until: deadline)

                    sampling.took()
                    sampling.take()
                }
            }
        }
    }
}
