// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Readings: where the host shows a value, copied into an ordinary state at a rate an author chooses - on the
// display's frames, by the display's time.
// Design: docs/design/core/journeys.md#readings

/// One reading of one journey into one target, at one rate - held by the element
/// that asked for it, known weakly by the source and by the board.
@MainActor
final class Sampling {
    /// The earliest frame this reading may be taken again, in the display clock's milliseconds.
    private var next: Double?

    /// The frame a reading is booked for - the end of the window a sample came inside - or nil for none.
    private(set) var booked: Double?

    /// The shortest time between readings, in milliseconds; nought is every frame.
    let window: Int

    /// Takes the reading. Replaced on every render: the closure holds that render's
    /// bindings.
    var take: @MainActor () -> Void

    /// A reading at a rate, and what one reading does.
    init(window: Int, take: @escaping @MainActor () -> Void) {
        self.window = window
        self.take = take
    }

    /// What the frame at `now` should do about a sample that changed, with the bookkeeping.
    func due(at now: Double) -> Due {
        if booked != nil { return .waiting }

        guard let next, now < next else {
            self.next = now + Double(max(0, window))
            return .now
        }

        booked = next
        return .waitUntil(next)
    }

    /// Takes the booked reading on the first frame at or past its time; answers whether it was taken.
    func takeBooked(at now: Double) -> Bool {
        guard let booked, now >= booked else { return false }

        self.booked = nil
        next = now + Double(max(0, window))
        take()
        return true
    }

    /// What a frame should do about a reading.
    enum Due: Equatable {
        /// Take it now. The window starts again from this frame.
        case now

        /// Take it on the first frame at or past this time - nobody is waiting for it yet.
        case waitUntil(Double)

        /// Do nothing: a reading is already booked and will cover this frame
        /// too.
        case waiting
    }
}

/// One reading, as the value it reads knows it: weakly.
@MainActor
final class WeakSampling {
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
        take: @escaping @MainActor () -> Void
    ) -> Sampling {
        let place = samplings.firstIndex { $0.target == target }

        if let place, let standing = samplings[place].held.sampling, standing.window == window {
            standing.take = take
            return standing
        }

        let made = Sampling(window: window, take: take)

        if let place {
            samplings[place].held = WeakSampling(made)
        } else {
            samplings.append((target, WeakSampling(made)))
        }
        return made
    }

    /// Runs every reading asked for of this value as its sample changes, on the frame at `now`; a
    /// reading inside its window is booked with the board for the window's end.
    func sampleTaken(at now: Double) {
        // A reading whose element has gone is swept.
        samplings.removeAll { $0.held.sampling == nil }

        for entry in samplings {
            guard let sampling = entry.held.sampling else { continue }

            switch sampling.due(at: now) {
            case .now:
                sampling.take()

            case .waiting:
                break

            case .waitUntil:
                Renderer.shared.board.book(sampling)
            }
        }
    }
}
