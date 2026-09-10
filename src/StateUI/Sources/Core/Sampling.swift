// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Reading a value the HOST is moving, so many times a second.
//
// The founding assumption everything here follows from: A STATE IS AT ITS
// VALUE THE MOMENT IT IS WRITTEN. `fade = 0.1` puts the destination on the
// state at once and the HOST walks the control there, so the tree always
// describes where the value is GOING. Reading such a state answers the
// destination, from the first frame to the last
// (`State.Storage.carryAsJourney`, whose `hostRead` is the destination).
//
// That is what makes a cadence over the state itself worth nothing: there is
// no sweep on this side to hold back - the number would be the same one, over
// and over. What sweeps is where the value HAS GOT TO - the JOURNEY - and the
// host sends that every cycle it moves, as lanes beside the destination
// (`StateCycle.Told` on the far side, `Renderer.cycleWritten` on this one).
// A body that reads `$fade.journey.value` is rebuilt on every one of them,
// which is the honest cost of printing a moving number; a body that reads
// `fade` alone is not, a value moving being nobody's reason to render.
//
// A SAMPLE is how an author asks for some of them anyway. `.samples($fade,
// into: $shown, .every(100))` copies where the value has got to into an
// ORDINARY state, ten times a second; the body reads THAT, and is rebuilt by
// it under the ordinary rules. The source goes on standing at its destination
// and goes on costing nothing.
//
// It stops by itself. A tick copies only what changed, so a value that has
// landed writes nothing and asks for nothing, and the host stops sending the
// moment the channel stops moving.
//
// WHY THE WINDOW LIVES HERE AND NOT ON THE STATE: one source may be sampled by
// two views into two states, at two rates - and each of those is its own
// reading with its own window, none of which is a fact about the source. That
// is what a cadence on the state could never say, and the reason this is a
// modifier rather than a rider on the declaration.

import Dispatch

/// One reading of one source into one target, at one rate.
///
/// Held by the source's `HostStorage`, keyed by the target's identity, so a
/// view describing itself again replaces its own reading rather than adding a
/// second one.
final class Sampling: @unchecked Sendable {
    /// Guards the window. The host writes from the thread MAUI draws on and
    /// the deadline's task resumes on another, which is the same crossing
    /// `State.Storage` keeps a queue for.
    private let guarded = DispatchQueue(label: "StateUI.Sampling")

    /// The earliest moment this reading may be taken again. Nothing until one
    /// has been taken.
    private var next: ContinuousClock.Instant?

    /// Whether a reading is already booked for the end of this window.
    private var waiting = false

    /// The shortest time between two readings, in milliseconds. Nought is
    /// every frame the host sends.
    let window: Int

    /// What one reading does, as this render wrote it.
    private var taking: @Sendable () -> Void

    /// Takes the reading: reads where the value has got to and writes it into
    /// the target, unless it is already there.
    ///
    /// REPLACED ON EVERY RENDER and read under the lock, because the closure
    /// holds the bindings the render that wrote it was handed - a state
    /// adopted since would otherwise be written through a box nothing reads -
    /// while a booked reading may be running it on the pool at that moment.
    /// The object itself lives on, which is what keeps the window.
    var take: @Sendable () -> Void {
        get { guarded.sync { taking } }
        set { guarded.sync { taking = newValue } }
    }

    /// - Parameters:
    ///   - window: the shortest time between two readings.
    ///   - take: what one reading does.
    init(window: Int, take: @escaping @Sendable () -> Void) {
        self.window = window
        self.taking = take
    }

    /// What this frame should do about the reading, and the bookkeeping for
    /// it, under one hold.
    ///
    /// - Parameter now: the moment the host wrote. Stated so a test can hold
    ///   the clock still rather than sleep.
    /// - Returns: what to do.
    func due(at now: ContinuousClock.Instant = .now) -> Due {
        guarded.sync {
            if waiting { return .waiting }

            guard let next, now < next else {
                self.next = now + .milliseconds(max(0, window))
                return .now
            }

            waiting = true
            return .waitUntil(next)
        }
    }

    /// Records that the reading that was waiting has been taken, and starts
    /// the next window from here.
    ///
    /// - Parameter now: the moment it was taken.
    func took(at now: ContinuousClock.Instant = .now) {
        guarded.sync {
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

extension HostStorage {
    /// Asks for a reading of this value into `target`, so many milliseconds
    /// apart - or hands this render's closure to the reading already standing
    /// there, which is what keeps its WINDOW.
    ///
    /// **THE WINDOW HAS TO SURVIVE THE RENDER THE READING'S OWN WRITE ASKS
    /// FOR.** A reading writes an ordinary state, that write asks for a
    /// render, and the render walks the very view that asked for the reading.
    /// Made afresh there, the window starts over: the next frame counts as a
    /// first frame, is read, asks for the render that resets it again - and a
    /// reading at any rate is taken on every frame the host sends.
    /// `StateTests.testAReadingSurvivesTheRenderItsOwnWriteAsks`.
    ///
    /// A CHANGED RATE IS A NEW READING, and starts with one taken at once:
    /// what the standing window is counting is a rate nobody asked for any
    /// more.
    ///
    /// - Parameters:
    ///   - target: the state the reading is written into, which is what it is
    ///     keyed by - so a view describing itself again replaces its own
    ///     rather than adding a second.
    ///   - window: the shortest time between two readings.
    ///   - take: what one reading does.
    func sample(into target: ObjectIdentifier, every window: Int, take: @escaping @Sendable () -> Void) {
        if let standing = samplings[target], standing.window == window {
            standing.take = take
            return
        }

        samplings[target] = Sampling(window: window, take: take)
    }

    /// Runs every reading somebody asked for of this value - what
    /// `Renderer.cycleWritten` calls after the host has written the lanes.
    ///
    /// A reading whose window has not passed BOOKS one for the end of it,
    /// which is what makes the last frame of a walk arrive rather than leaving
    /// the sample one frame short of where the value stopped.
    func sampleTaken() {
        for sampling in samplings.values {
            switch sampling.due() {
            case .now:
                sampling.take()

            case .waiting:
                break

            case .waitUntil(let deadline):
                // `Task.sleep` and not a Foundation timer, for the reason
                // Core/Ticker.swift gives: nothing turns a RunLoop here.
                Task {
                    try? await Task.sleep(until: deadline)

                    sampling.took()
                    sampling.take()
                }
            }
        }
    }
}
