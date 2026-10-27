// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A view a layout places, at a rectangle in its layout's coordinates, y growing down.
@_spi(Host) @MainActor public protocol PlacedView: AnyObject {
    /// The rectangle the view stands at.
    var placedFrame: Rect { get set }

    /// Where the view's place travels, told as it sets out, and nil once it stands: a layout lays its children out
    /// at that size while its place travels, never at the sizes it passes through.
    /// Design: docs/design/host/motion.md#a-layout-bound-for-a-size
    func travels(to destination: Rect?)
}

extension PlacedView {
    /// Nothing of the view's own follows where its place travels.
    public func travels(to destination: Rect?) {}
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
        var destination = Rect(x: 0, y: 0, width: 0, height: 0)
        /// The natural size of the words a traveling child lays out; nil for one laying out none.
        var words: LayoutSize?

        /// Where the child stands while its place passes `standing`.
        func frame(_ standing: Rect) -> Rect {
            words.map { LayoutMotion.room(standing, destination: destination, words: $0) } ?? standing
        }
    }

    private let animator: Animator
    private let now: () -> Double
    private let reducesMotion: () -> Bool
    private var seats: [UInt64: Seat] = [:]

    /// The application's motion, which a layout that says nothing of its own animates under.
    public var applicationMotion: Motion = .none

    /// Called when an animation starts, so the frame clock is held while it runs.
    public var onStart: () -> Void = {}

    /// Layout motion whose animations `animator` advances, on `now`'s time.
    public init(animator: Animator, now: @escaping () -> Double, reducesMotion: @escaping () -> Bool) {
        self.animator = animator
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
        let law = motion.map { $0.motion.kind == .inherited ? applicationMotion : $0.motion } ?? applicationMotion
        return law.animates && !reducesMotion() ? law : nil
    }

    /// Stands `view` at `target`, or on its way there; `stated` are the sides it sizes itself, and a view laying out
    /// `words` is measured by `natural` as its place sets out.
    public func place(
        _ view: any PlacedView,
        mount: UInt64,
        at target: Rect,
        stated: MotionLanes,
        words: Bool,
        natural: () -> LayoutSize,
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
        let key = AnimationTarget.placed(mount)
        let destination = Self.lanes(target)
        let running = animator.animation(for: key)

        // The same place asked for again keeps its animation rather than starting it over.
        if let running, running.destination == destination {
            if let standing = seat.standing { view.placedFrame = seat.frame(standing) }
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

        let animation = Animation(from: start, destination: destination, velocity: velocity, motion: arrangement.law, began: now())

        guard !animation.arrives else {
            arrive(view, at: target, mount: mount)
            return
        }

        let standing = Self.rect(start)
        animator.start(animation, for: key)
        seats[mount]?.standing = standing
        seats[mount]?.destination = target
        seats[mount]?.words = words ? natural() : nil
        view.travels(to: target)
        view.placedFrame = seats[mount]?.frame(standing) ?? standing
        onStart()
    }

    /// Stands each animating child where the animator put it.
    public func follow(_ steps: [AnimationStep]) {
        for step in steps {
            guard case .placed(let mount) = step.target else { continue }

            let standing = Self.rect(step.value)
            seats[mount]?.standing = step.rested ? nil : standing
            if step.rested {
                seats[mount]?.words = nil
                seats[mount]?.view?.travels(to: nil)
            }
            seats[mount]?.view?.placedFrame = seats[mount]?.frame(standing) ?? standing
        }
    }

    /// Forgets the place of an element that leaves the tree.
    public func remove(mount: UInt64) {
        seats[mount] = nil
        animator.halt(.placed(mount))
    }

    private func arrive(_ view: any PlacedView, at target: Rect, mount: UInt64) {
        animator.halt(.placed(mount))
        seats[mount]?.standing = nil
        seats[mount]?.words = nil
        view.travels(to: nil)
        view.placedFrame = target
    }

    /// Where a child laying out words of the natural size `words` stands while its place passes `standing` on its
    /// way to `destination`: no narrower than its words need there - their natural size, or the destination's where
    /// they wrap in it. Design: docs/design/host/motion.md#words-on-the-way
    nonisolated static func room(_ standing: Rect, destination: Rect, words: LayoutSize) -> Rect {
        let needs = words.width > destination.width
            ? LayoutSize(width: destination.width, height: destination.height)
            : LayoutSize(width: words.width, height: min(words.height, destination.height))
        return Rect(
            x: standing.x, y: standing.y,
            width: max(standing.width, needs.width), height: max(standing.height, needs.height))
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
