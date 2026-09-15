// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// How one arrangement of a layout places its children.
struct AppKitArrangement {
    /// The law children travel and fade in under.
    var law: Motion = .none

    /// Which parts of a changed place travel; none where every child arrives.
    var lanes: MotionLanes = []

    /// Whether a child that joins the layout fades in.
    var fades = false
}

/// The places layouts give their children, walked there instead of jumped to.
///
/// A layout works out where each child goes; this decides where the child
/// stands on the way. Why an arrangement happens is the one thing it does not
/// say about itself, and it decides everything here:
///
/// - A patch that reached the layout since its last arrangement means it holds
///   something different - a row inserted, a card grown - and its children
///   travel, under the layout's own motion or, while it says nothing of its
///   own, the application's. A child that joins it fades in.
/// - No patch means the room itself is moving - a window dragged, a sidebar
///   pulled - and every child follows it exactly, because a child that glides
///   after the reader's own hand is late on every frame. A layout whose own
///   width changed is that case even with a patch: its width is its parent's
///   to say.
/// - A layout's first arrangement is an arrival: the first thing anyone sees
///   is the thing itself.
///
/// A size a child states for itself arrives while its place travels: a stated
/// size is either still or already moving on its own. And where a frame under
/// the layout is read, every child arrives, because each step of a walk would
/// hand the reader a room nobody chose.
@MainActor
final class AppKitLayoutMotion {
    /// The place a layout gave one child.
    private struct Seat {
        /// The child, held weakly: a view the tree dropped is not kept alive
        /// for its place.
        weak var view: NSView?

        /// Where it stands while its trip is under way.
        var standing: NSRect?
    }

    private let walker: AppKitWalker
    private let now: () -> Double
    private let reducesMotion: () -> Bool
    private var seats: [UInt64: Seat] = [:]

    /// How a layout that says nothing of its own moves its children: the
    /// application's motion, which the application always says once.
    var applicationMotion: Motion = .none

    /// Called when a trip starts, so the frame clock is held to walk it.
    var onStart: () -> Void = {}

    /// Layout motion whose trips `walker` walks, on `now`'s time.
    init(walker: AppKitWalker, now: @escaping () -> Double, reducesMotion: @escaping () -> Bool) {
        self.walker = walker
        self.now = now
        self.reducesMotion = reducesMotion
    }

    /// How an arrangement places a layout's children.
    ///
    /// - Parameters:
    ///   - said: Whether a patch reached the layout since it last arranged.
    ///   - resized: Whether its own width changed since then.
    ///   - motion: The layout's own motion; nil while it says nothing of its
    ///     own.
    ///   - framesRead: Whether its frame, or any frame under it, is read.
    func arrangement(
        said: Bool,
        resized: Bool,
        motion: HostLayoutMotion?,
        framesRead: Bool
    ) -> AppKitArrangement {
        let lanes = motion?.lanes ?? .all

        guard said, !lanes.isEmpty, let law = law(of: motion) else {
            return AppKitArrangement()
        }

        return AppKitArrangement(
            law: law,
            lanes: resized || framesRead ? [] : lanes,
            fades: true)
    }

    /// The law `motion` resolves to - an element's own, or the application's
    /// where it says nothing - and nil where it moves nothing: a snap, an
    /// engine's value, or a reader who asked for less movement.
    func law(of motion: HostLayoutMotion?) -> Motion? {
        let law = motion.map { $0.motion.isInherited ? applicationMotion : $0.motion }
            ?? applicationMotion
        return Self.moves(law) && !reducesMotion() ? law : nil
    }

    /// Stands `item` at `target`, or on its way there.
    func place(_ item: AppKitLayoutItem, at target: NSRect, in arrangement: AppKitArrangement) {
        let view = item.view
        let mount = item.mount
        guard mount != 0 else {
            view.frame = target
            return
        }

        // A CHILD NOBODY HAS PLACED YET is already where it belongs - and one
        // joining a layout that was already standing arrives by fading in.
        guard let seat = seats[mount] else {
            seats[mount] = Seat(view: view)
            view.frame = target
            if arrangement.fades { item.fadeIn?(arrangement.law) }
            return
        }

        seats[mount]?.view = view
        let key = AppKitTripTarget.placed(mount)
        let destination = Self.lanes(target)
        let running = walker.trip(for: key)

        // THE PLACE HAS NOT CHANGED. An arrangement is asked for whenever
        // anything invalidates, and a trip aimed again on each would start its
        // clock again every time and never arrive.
        if let running, running.destination == destination {
            if let standing = seat.standing { view.frame = standing }
            return
        }

        let from = seat.standing ?? view.frame
        let lanes = arrangement.lanes.subtracting(Self.stated(item))

        // THERE IS NO HALF-WAY BETWEEN NOWHERE AND SOMEWHERE: a view with no
        // size yet, or given none, is not a place to travel from or to.
        guard !lanes.isEmpty, Self.isReal(from), Self.isReal(target) else {
            arrive(view, at: target, mount: mount)
            return
        }

        // FROM WHERE IT STANDS: a trip under way is bent from where it has
        // reached, at the speed it has, rather than started again.
        let position = running?.position(at: now())
        var start = position?.value ?? Self.lanes(from)
        var velocity = position?.velocity ?? [0, 0, 0, 0]

        // A lane that does not travel starts where it is going, standing still.
        for (index, lane) in Self.order.enumerated() where !lanes.contains(lane) {
            start[index] = destination[index]
            velocity[index] = 0
        }

        let trip = AppKitTrip(
            from: start,
            destination: destination,
            velocity: velocity,
            motion: arrangement.law,
            began: now())

        guard !trip.arrives else {
            arrive(view, at: target, mount: mount)
            return
        }

        let standing = Self.rect(start)
        walker.start(trip, for: key)
        seats[mount]?.standing = standing
        view.frame = standing
        onStart()
    }

    /// Stands each travelling child where a step of the walker put it.
    func follow(_ steps: [AppKitStep]) {
        for step in steps {
            guard case .placed(let mount) = step.target else { continue }

            let standing = Self.rect(step.value)
            seats[mount]?.standing = step.rested ? nil : standing
            seats[mount]?.view?.frame = standing
        }
    }

    /// Forgets the place of an element that leaves the tree, or is adopted -
    /// which then arrives.
    func remove(mount: UInt64) {
        seats[mount] = nil
        walker.halt(.placed(mount))
    }

    private func arrive(_ view: NSView, at target: NSRect, mount: UInt64) {
        walker.halt(.placed(mount))
        seats[mount]?.standing = nil
        view.frame = target
    }

    /// Whether a motion walks anything: neither a snap nor an engine's own.
    private static func moves(_ motion: Motion) -> Bool {
        !motion.isInherited && !motion.isCustom && motion.factor.isFinite
            && !(motion.law == .eased && motion.millis == 0)
    }

    /// The sides of its place a child states for itself.
    private static func stated(_ item: AppKitLayoutItem) -> MotionLanes {
        var stated: MotionLanes = []
        if item.width != nil { stated.insert(.width) }
        if item.height != nil { stated.insert(.height) }
        return stated
    }

    private static func isReal(_ rect: NSRect) -> Bool {
        rect.width > 0 && rect.height > 0
    }

    /// The lanes of a place, in trip order: across, down, wide, tall.
    private static let order: [MotionLanes] = [.x, .y, .width, .height]

    private static func lanes(_ rect: NSRect) -> [Double] {
        [rect.minX, rect.minY, rect.width, rect.height].map(Double.init)
    }

    private static func rect(_ lanes: [Double]) -> NSRect {
        NSRect(x: lanes[0], y: lanes[1], width: lanes[2], height: lanes[3])
    }
}

/// A layout whose children travel to the places a patch gives them.
///
/// Its arithmetic is its own. It begins each arrangement with
/// `beginArrangement()` and hands every child's place to `place(_:at:)`
/// instead of setting the child's frame.
@MainActor
class AppKitTravellingLayout: AppKitHitTestView {
    /// Where the children's places are walked; nil places them at once.
    weak var layoutMotion: AppKitLayoutMotion?

    /// The layout's own motion, as its patches said it; nil while it says
    /// nothing of its own.
    var motion: HostLayoutMotion?

    /// Whether this layout's frame, or any frame under it, is read.
    var framesRead = false

    /// Whether a patch reached the layout since its last arrangement.
    private var patched = false

    /// The width of the last arrangement; nil before the first.
    private var arrangedWidth: CGFloat?

    private var arrangement = AppKitArrangement()

    /// Notes that a patch reached the layout: its next arrangement places
    /// what the patch changed.
    func patchArrived() {
        patched = true
    }

    /// Starts an arrangement, deciding once for every child how it is placed.
    func beginArrangement() {
        let width = bounds.width
        let said = patched && arrangedWidth != nil
        let resized = arrangedWidth.map { abs($0 - width) > 0.5 } ?? false
        patched = false
        arrangedWidth = width

        arrangement = layoutMotion?.arrangement(
            said: said,
            resized: resized,
            motion: motion,
            framesRead: framesRead) ?? AppKitArrangement()
    }

    /// Stands `item` at `frame`, or on its way there.
    func place(_ item: AppKitLayoutItem, at frame: NSRect) {
        guard let layoutMotion else {
            item.view.frame = frame
            return
        }

        layoutMotion.place(item, at: frame, in: arrangement)
    }
}
#endif
