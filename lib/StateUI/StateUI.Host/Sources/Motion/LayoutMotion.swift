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

    /// The size of the new words a view laying out words in a box of its own holds back while its box grows to hold
    /// them, and nil once it shows them: meanwhile it shows the words it showed before, and is measured at this size.
    /// Set nil as it stands, it forgets its former words. Design: docs/design/host/motion.md#words-on-the-way
    var heldWords: LayoutSize? { get set }
}

extension PlacedView {
    /// Nothing of the view's own follows where its place travels.
    public func travels(to destination: Rect?) {}

    /// A view laying out no words in a box holds none back.
    public var heldWords: LayoutSize? {
        get { nil }
        set {}
    }
}

/// How one arrangement of a layout places its children.
@_spi(Host) public struct Arrangement {
    /// The timing children animate and fade in under; none where they arrive.
    public var law: Motion

    /// Which sides of a changed place animate; none where every child arrives.
    public var lanes: MotionLanes

    /// Whether a patch reached the layout as it stood: a child given its first place joins it.
    public var joins: Bool

    /// An arrangement that animates `lanes` under `law`; a child given its first place joins a standing layout
    /// when `joins`.
    public init(law: Motion = .none, lanes: MotionLanes = [], joins: Bool = false) {
        self.law = law
        self.lanes = lanes
        self.joins = joins
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
        /// The place its layout last gave the child, and the room that layout laid out in.
        var placed = Rect(x: 0, y: 0, width: 0, height: 0)
        var room: LayoutSize?
        /// The natural size of the words a traveling child lays out; nil for one laying out none.
        var words: LayoutSize?
        /// Whether the child holds its new words back, its box growing with its former ones.
        var holds = false

        /// Where the child stands while its place passes `standing`.
        func frame(_ standing: Rect) -> Rect {
            guard let words, !holds else { return standing }
            return LayoutMotion.room(standing, destination: destination, words: words)
        }
    }

    private let animator: Animator
    private let now: () -> Double
    private let reducesMotion: () -> Bool
    private var seats: [UInt64: Seat] = [:]

    /// How many views have a seat.
    var entries: Int { seats.count }

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

    /// How an arrangement places a layout's children: `said` when a patch reached the layout, `resized` when its
    /// own width changed. Whether a frame is read changes nothing: a reader of the layout stage is told the
    /// destination, one of the presentation stage each place on the way.
    public func arrangement(said: Bool, resized: Bool, motion: HostLayoutMotion?) -> Arrangement {
        let lanes = motion?.lanes ?? .all

        guard said, !lanes.isEmpty, let law = law(of: motion) else { return Arrangement(joins: said) }

        return Arrangement(law: law, lanes: resized ? [] : lanes, joins: true)
    }

    /// How a child that is a body is placed in an arrangement whose other children are placed as `arrangement`
    /// says: a body of none arrives; one answering a change travels on its spring where a patch `said` the
    /// arrangement and the layout's own width stands, whatever the layout's own motion; one following its place
    /// travels on its spring whenever its place moves. Under less motion it arrives.
    /// Design: docs/design/host/motion.md#a-child-that-is-a-body
    public func arrangement(
        of body: LayoutBody, said: Bool, resized: Bool, among arrangement: Arrangement
    ) -> Arrangement {
        guard let spring = body.host, !reducesMotion(), spring.follows || (said && !resized)
        else { return Arrangement(joins: arrangement.joins) }

        let law = Motion.spring(response: .milliseconds(Int64(spring.milliseconds.rounded())), damping: spring.damping)
        return Arrangement(law: law, lanes: .all, joins: arrangement.joins)
    }

    /// Told as a place is given, as one sets out on its way, and as that way ends: what watches the movements a
    /// change started.
    var placing: ((UInt64) -> Void)?
    var born: ((UInt64) -> Void)?
    var ended: ((UInt64, PresentationChanges.End) -> Void)?

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
        words: LaidOutWords,
        natural: () -> LayoutSize,
        enter: ((LayoutEntry) -> Void)?,
        in arrangement: Arrangement,
        room: LayoutSize?
    ) {
        guard mount != 0 else {
            view.placedFrame = target
            return
        }
        placing?(mount)

        // A child with no seat yet is already where it belongs, and enters there.
        guard let seat = seats[mount] else {
            var seat = Seat(view: view)
            (seat.placed, seat.room) = (target, room)
            seats[mount] = seat
            view.heldWords = nil
            view.placedFrame = target
            enter?(arrangement.joins ? .joining(under: arrangement.law) : .appearing)
            return
        }

        seats[mount]?.view = view
        seats[mount]?.placed = target
        seats[mount]?.room = room
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
        let measured = words == .none ? nil : natural()
        let holds = words == .boxed && measured.map { $0.width > standing.width + 0.5 } == true
        if running != nil { ended?(mount, .superseded) }
        animator.start(animation, for: key)
        born?(mount)
        seats[mount]?.standing = standing
        seats[mount]?.destination = target
        seats[mount]?.words = measured
        seats[mount]?.holds = holds
        view.heldWords = holds ? measured : nil
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
            if step.rested { ended?(mount, .rested) }
            if step.rested {
                seats[mount]?.words = nil
                seats[mount]?.holds = false
                seats[mount]?.view?.heldWords = nil
                seats[mount]?.view?.travels(to: nil)
            } else if let seat = seats[mount], seat.holds, standing.width >= (seat.words?.width ?? 0) - 0.5 {
                // The box holds the new words: they show.
                seats[mount]?.holds = false
                seats[mount]?.view?.heldWords = nil
            }
            seats[mount]?.view?.placedFrame = seats[mount]?.frame(standing) ?? standing
        }
    }

    /// Where the child `mount` stands on its way and the place it travels to; nil for one standing at its place.
    public func travel(of mount: UInt64) -> (standing: Rect, destination: Rect)? {
        guard let seat = seats[mount], let standing = seat.standing else { return nil }
        return (seat.frame(standing), seat.destination)
    }

    /// The place its layout last gave the child `mount`, and the room that layout laid out in; nil for a child no
    /// layout placed.
    public func placed(_ mount: UInt64) -> (place: Rect, room: LayoutSize?)? {
        seats[mount].map { ($0.placed, $0.room) }
    }

    /// Forgets the place of an element that leaves the tree.
    public func remove(mount: UInt64) {
        seats[mount] = nil
        if animator.animation(for: .placed(mount)) != nil { ended?(mount, .detached) }
        animator.halt(.placed(mount))
    }

    private func arrive(_ view: any PlacedView, at target: Rect, mount: UInt64) {
        if animator.animation(for: .placed(mount)) != nil { ended?(mount, .superseded) }
        animator.halt(.placed(mount))
        seats[mount]?.standing = nil
        seats[mount]?.words = nil
        seats[mount]?.holds = false
        view.heldWords = nil
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
