// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A view a layout places, at a rectangle in its layout's coordinates, y growing down.
@_spi(Host) @MainActor public protocol PlacedView: AnyObject {
    /// The rectangle the view stands at.
    var placedFrame: Rect { get set }
}

/// How one arrangement of a layout places its children.
@_spi(Host) public struct Arrangement {
    /// The timing children animate and fade in under.
    public var law: Motion

    /// Which sides of a changed place animate; none where every child arrives.
    public var lanes: MotionLanes

    /// Whether a child that joins the layout fades in.
    public var fades: Bool

    /// An arrangement that animates `lanes` under `law`, fading in a joining child when `fades`.
    public init(law: Motion = .none, lanes: MotionLanes = [], fades: Bool = false) {
        self.law = law
        self.lanes = lanes
        self.fades = fades
    }
}

/// The places layouts give their children, animated there instead of jumped to.
/// Design: docs/design/host/motion.md#layout-motion
@_spi(Host) @MainActor public final class LayoutMotion {
    /// The place a layout gave one child; the view is held weakly.
    private struct Seat {
        weak var view: (any PlacedView)?
        var standing: Rect?
    }

    private let walker: Walker
    private let now: () -> Double
    private let reducesMotion: () -> Bool
    private var seats: [UInt64: Seat] = [:]

    /// The application's motion, which a layout that says nothing of its own animates under.
    public var applicationMotion: Motion = .none

    /// Called when an animation starts, so the frame clock is held to walk it.
    public var onStart: () -> Void = {}

    /// Layout motion whose animations `walker` walks, on `now`'s time.
    public init(walker: Walker, now: @escaping () -> Double, reducesMotion: @escaping () -> Bool) {
        self.walker = walker
        self.now = now
        self.reducesMotion = reducesMotion
    }

    /// How an arrangement places a layout's children: `said` when a patch reached the layout,
    /// `resized` when its own width changed, `framesRead` when a frame under it is read.
    public func arrangement(said: Bool, resized: Bool, motion: HostLayoutMotion?, framesRead: Bool) -> Arrangement {
        let lanes = motion?.lanes ?? .all

        guard said, !lanes.isEmpty, let law = law(of: motion) else { return Arrangement() }

        return Arrangement(law: law, lanes: resized || framesRead ? [] : lanes, fades: true)
    }

    /// The timing `motion` resolves to, or nil where nothing animates.
    public func law(of motion: HostLayoutMotion?) -> Motion? {
        let law = motion.map { $0.motion.isInherited ? applicationMotion : $0.motion } ?? applicationMotion
        return Self.moves(law) && !reducesMotion() ? law : nil
    }

    /// Stands `view` at `target`, or on its way there; `stated` are the sides it sizes itself.
    public func place(
        _ view: any PlacedView,
        mount: UInt64,
        at target: Rect,
        stated: MotionLanes,
        fadeIn: ((Motion) -> Void)?,
        in arrangement: Arrangement
    ) {
        guard mount != 0 else {
            view.placedFrame = target
            return
        }

        // A child with no seat yet is already where it belongs; one joining a standing layout fades in.
        guard let seat = seats[mount] else {
            seats[mount] = Seat(view: view)
            view.placedFrame = target
            if arrangement.fades { fadeIn?(arrangement.law) }
            return
        }

        seats[mount]?.view = view
        let key = TripTarget.placed(mount)
        let destination = Self.lanes(target)
        let running = walker.trip(for: key)

        // The same place asked for again keeps its animation rather than starting it over.
        if let running, running.destination == destination {
            if let standing = seat.standing { view.placedFrame = standing }
            return
        }

        let from = seat.standing ?? view.placedFrame
        let lanes = arrangement.lanes.subtracting(stated)

        guard !lanes.isEmpty, Self.isReal(from), Self.isReal(target) else {
            arrive(view, at: target, mount: mount)
            return
        }

        // A running animation bends from where it has reached, at the speed it has.
        let position = running?.position(at: now())
        var start = position?.value ?? Self.lanes(from)
        var velocity = position?.velocity ?? [0, 0, 0, 0]

        for (index, lane) in Self.order.enumerated() where !lanes.contains(lane) {
            start[index] = destination[index]
            velocity[index] = 0
        }

        let trip = Trip(from: start, destination: destination, velocity: velocity, motion: arrangement.law, began: now())

        guard !trip.arrives else {
            arrive(view, at: target, mount: mount)
            return
        }

        let standing = Self.rect(start)
        walker.start(trip, for: key)
        seats[mount]?.standing = standing
        view.placedFrame = standing
        onStart()
    }

    /// Stands each animating child where a step of the walker put it.
    public func follow(_ steps: [Step]) {
        for step in steps {
            guard case .placed(let mount) = step.target else { continue }

            let standing = Self.rect(step.value)
            seats[mount]?.standing = step.rested ? nil : standing
            seats[mount]?.view?.placedFrame = standing
        }
    }

    /// Forgets the place of an element that leaves the tree, or is adopted and then arrives.
    public func remove(mount: UInt64) {
        seats[mount] = nil
        walker.halt(.placed(mount))
    }

    private func arrive(_ view: any PlacedView, at target: Rect, mount: UInt64) {
        walker.halt(.placed(mount))
        seats[mount]?.standing = nil
        view.placedFrame = target
    }

    /// Whether a timing animates anything: neither a snap nor an engine's own.
    private static func moves(_ motion: Motion) -> Bool {
        !motion.isInherited && !motion.isCustom && motion.factor.isFinite
            && !(motion.law == .eased && motion.millis == 0)
    }

    private static func isReal(_ rect: Rect) -> Bool {
        rect.width > 0 && rect.height > 0
    }

    /// A place's lanes in animation order: across, down, wide, tall.
    private static let order: [MotionLanes] = [.x, .y, .width, .height]

    private static func lanes(_ rect: Rect) -> [Double] {
        [rect.x, rect.y, rect.width, rect.height]
    }

    private static func rect(_ lanes: [Double]) -> Rect {
        Rect(x: lanes[0], y: lanes[1], width: lanes[2], height: lanes[3])
    }
}
