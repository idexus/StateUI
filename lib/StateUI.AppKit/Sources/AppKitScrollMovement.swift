// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// One scroller's movement as the host knows it: whether the reader is moving
/// it, what it has to say on the display's next frame, and the moment a
/// movement of the reader's comes to rest.
///
/// THE SCROLLING IS THE PLATFORM'S. A drag, a throw, a wheel and a key move the
/// scroller under AppKit's own physics, and nothing here aims, shortens or
/// corrects them. What this adds is what AppKit does not say in one shape:
/// where a movement went, frame by frame, and when it is over.
///
/// REPORTS WAIT FOR THE DISPLAY'S FRAME. AppKit moves the clip view from inside
/// its own frame step, and a report rendered there holds that frame: the scroll
/// events behind it then arrive merged into one jump. A move joins the move
/// before it, so a frame says where the scroller went rather than every step.
///
/// REST is said once per movement, and only when the offset moved: when a live
/// scroll ends, or - for a movement no live scroll brackets, a wheel's click -
/// once the offset has stood still for `restAfter` of the frame clock's time.
/// A moving scroller keeps the frames coming, so the quiet is counted in the
/// display's own time and a hand-wound clock reproduces every rest.
@MainActor
final class AppKitScrollMovement {
    /// Something the scroller says on a display frame.
    enum Report: Equatable {
        /// It went from one offset to another.
        case moved(from: NSPoint, to: NSPoint)

        /// A movement of the reader's came to rest.
        case rested
    }

    /// How long a movement no live scroll brackets stands still before it is
    /// at rest, in the frame clock's milliseconds.
    static let restAfter = 120.0

    /// Asks for the display's frames: the scroller is moving, or it has
    /// something to say.
    var onFramesWanted: () -> Void = {}

    /// Whether a movement of the reader's is under way.
    private(set) var isMoving = false

    /// Whether the offset moved during the movement under way.
    private var moved = false

    /// Whether AppKit's live scroll brackets the movement, and so ends it.
    private var live = false

    /// Whether the reader moved the scroller since the last frame.
    private var movedSinceFrame = false

    /// The frame from which the offset has stood still.
    private var stillSince: Double?

    /// What the scroller has to say on the display's next frame, in order.
    private var reports: [Report] = []

    /// Whether the scroller needs the display's frames.
    var wantsFrames: Bool { isMoving || !reports.isEmpty }

    /// Begins a movement.
    func begin() {
        isMoving = true
        moved = false
        movedSinceFrame = false
        stillSince = nil
        onFramesWanted()
    }

    /// AppKit's live scroll began: the movement lasts until it ends.
    func liveScrollBegan() {
        live = true
        begin()
    }

    /// AppKit's live scroll ended, and the movement with it.
    func liveScrollEnded() {
        live = false
        rest()
    }

    /// The reader moved the scroller from `old` to `new`.
    func readerMoved(from old: NSPoint, to new: NSPoint) {
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
    func rest() {
        guard isMoving else { return }
        isMoving = false
        stillSince = nil

        if moved {
            reports.append(.rested)
            onFramesWanted()
        }
        moved = false
    }

    /// One frame of the display's clock: counts the quiet, and takes what the
    /// scroller has to say, in order - where it went, and that it came to rest.
    func frame(now: Double) -> [Report] {
        if isMoving, !live {
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
#endif
