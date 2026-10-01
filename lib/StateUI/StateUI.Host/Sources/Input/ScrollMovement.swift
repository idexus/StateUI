// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One scroller's movement as its host knows it: whether the user is moving it,
/// what it says on the display's next frame, and when a movement comes to rest.
/// Design: docs/design/host/runtime.md#a-scrollers-movement
@_spi(Host) @MainActor public final class ScrollMovement {
    /// Something the scroller says on a display frame.
    public enum Report: Equatable, Sendable {
        /// It went from one offset to another.
        case moved(from: Point, to: Point)

        /// A movement of the user's came to rest.
        case rested
    }

    /// How long a movement nobody holds stands still before it is at rest, in the frame clock's milliseconds.
    public static let restAfter = 120.0

    /// Asks for the display's frames: the scroller is moving, or it has something to say.
    public var onFramesWanted: () -> Void = {}

    /// Whether a movement of the user's is under way.
    public private(set) var isMoving = false

    /// Whether the offset moved during the movement under way.
    private var moved = false

    /// Whether the user holds the scroller, so the movement cannot rest.
    private var held = false

    /// Whether the user moved the scroller since the last frame.
    private var movedSinceFrame = false

    /// The frame from which the offset has stood still.
    private var stillSince: Double?

    /// What the scroller has to say on the display's next frame, in order.
    private var reports: [Report] = []

    /// A scroller nobody moves.
    public init() {}

    /// Whether the scroller needs the display's frames.
    public var wantsFrames: Bool { isMoving || !reports.isEmpty }

    /// Begins a movement.
    public func begin() {
        isMoving = true
        moved = false
        movedSinceFrame = false
        stillSince = nil
        onFramesWanted()
    }

    /// The user took hold of the scroller - a live scroll, a finger down: the movement cannot rest until they let go.
    /// A hold that catches a movement still under way, a throw, carries it on, so it rests once.
    public func holdBegan() {
        held = true
        if !isMoving { begin() }
    }

    /// The user let go. Where the hold ran its throw out, as a live scroll does, the movement `rests` at once;
    /// otherwise what the scroller does on its own rests once it has stood still.
    public func holdEnded(rests: Bool) {
        held = false
        stillSince = nil
        if rests { rest() }
    }

    /// The user moved the scroller from `old` to `new`.
    public func userMoved(from old: Point, to new: Point) {
        guard old != new else { return }
        if !isMoving { begin() }
        moved = true
        movedSinceFrame = true

        if case .moved(let from, _)? = reports.last {
            reports[reports.count - 1] = .moved(from: from, to: new)
        } else {
            reports.append(.moved(from: old, to: new))
        }
        onFramesWanted()
    }

    /// Ends the movement under way where it stands.
    public func rest() {
        guard isMoving else { return }
        isMoving = false
        stillSince = nil

        if moved {
            reports.append(.rested)
            onFramesWanted()
        }
        moved = false
    }

    /// One frame of the display's clock: counts the quiet, and takes what the scroller has to say, in order.
    public func frame(now: Double) -> [Report] {
        if isMoving, !held {
            if movedSinceFrame || stillSince == nil {
                stillSince = now
                movedSinceFrame = false
            } else if let stillSince, now - stillSince >= Self.restAfter {
                rest()
            }
        }

        defer { reports.removeAll(keepingCapacity: true) }
        return reports
    }
}
