// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The presentation changes a tree's renders carry. Each watches the movements its patch started under the view
/// it aims at - as the patch is applied, and in the layout pass that places what the patch said - answers that
/// it was applied, and answers how they ended once the last has.
/// Design: docs/design/host/motion.md#a-change-and-what-it-started
@_spi(Host) @MainActor public final class PresentationChanges {
    /// How a movement a change watches ended.
    public enum End: Equatable, Sendable {
        /// At rest where it was sent.
        case rested
        /// Sent elsewhere by a later write.
        case superseded
        /// Stopped where it stood.
        case stopped
        /// Its view left.
        case detached
        /// Its view's exit was cut short by the budget of views kept as they leave.
        case limited
    }

    /// A movement a change watches: a property on its way, an element's place, or a run of a state's channel.
    enum Member: Hashable {
        case described(DescribedKey)
        case placed(UInt64)
        case run(state: Int32, number: Int)
    }

    private final class Group {
        let change: HostPresentationChange
        let root: UInt64
        var members: Set<Member> = []
        var reasons: [PresentationInterruption] = []

        /// The elements under the view the patch reached, until the layout placing each has arranged; and the
        /// frames its layout window still lasts.
        var touched: Set<UInt64> = []
        var framesLeft = 0

        /// The states the change's writes sent somewhere that are shown under the view, until a run of each is
        /// taken.
        var states: Set<Int32> = []

        /// Whether nothing is left for the group's window to wait for.
        var awaitsNothing: Bool { touched.isEmpty && states.isEmpty }

        init(_ change: HostPresentationChange, root: UInt64) {
            self.change = change
            self.root = root
        }
    }

    /// How many frames after its patch a change waits for a layout pass to place what the patch said: a toolkit
    /// that lays out after its frame's callback has done so by the second.
    static let layoutWindow = 2

    private let core: CoreLink

    /// The groups whose render is being applied: what is born now joins them.
    private var opened: [Group] = []

    /// The groups waiting for their members to end, in the order made.
    private var waiting: [Group] = []

    /// The elements whose children were given places since the last frame ended.
    private var arranged: Set<UInt64> = []

    /// How the exit of an element being released ended, by its mount: what its movements end as.
    private var exits: [UInt64: End] = [:]

    /// The runs born since the render before and still under way, by state: a write's run is born in the core's
    /// cycle, before the render that carries its change.
    private var recent: [Int32: Set<Int>] = [:]

    /// Changes answered through `core`.
    public init(core: CoreLink) {
        self.core = core
    }

    /// How many changes wait for a movement to end, or for their layout window.
    public var waitingCount: Int { waiting.count }

    /// Whether a change waits for a layout pass: the frames go on for it.
    public var wantsFrames: Bool { waiting.contains { $0.framesLeft > 0 } }

    /// A render brings `changes`, before its patch is applied to `tree`: each opens on the view it aims at, and
    /// one nothing shows is answered at once.
    public func begin(_ changes: [HostPresentationChange], in tree: MountedTree) {
        for change in changes {
            guard let element = tree.root?.element(at: change.place), element.lifecycle == .active else {
                core.answer(change.applied, applied: .notPresented)
                core.answer(change.settled, settled: .notPresented)
                continue
            }
            let group = Group(change, root: element.mount)
            for state in change.states where tree.shows(state, under: element.mount) {
                let runs = recent[state] ?? []
                if runs.isEmpty { group.states.insert(state) }
                for number in runs { group.members.insert(.run(state: state, number: number)) }
            }
            opened.append(group)
        }
    }

    /// A run of `state` was born: a change that waits for one takes it.
    func runBorn(_ state: Int32, _ number: Int) {
        recent[state, default: []].insert(number)
        for group in opened + waiting where group.states.remove(state) != nil {
            group.members.insert(.run(state: state, number: number))
        }
    }

    /// The run `number` of `state` ended as `outcome`.
    func runEnded(_ state: Int32, _ number: Int, as outcome: HostMotionOutcome) {
        recent[state]?.remove(number)
        if recent[state]?.isEmpty == true { recent[state] = nil }
        let end: End = switch outcome {
        case .animated, .immediate: .rested
        case .superseded: .superseded
        case .stopped: .stopped
        case .detached: .detached
        }
        ended(.run(state: state, number: number), as: end)
    }

    /// The patch being applied says something of `element`: every open change it stands under remembers it, for
    /// the layout pass that places what the patch said.
    func reached(_ element: MountedElement) {
        guard !opened.isEmpty else { return }

        let above = Self.mounts(from: element)
        for group in opened where above.contains(group.root) { group.touched.insert(element.mount) }
    }

    /// The movement `member` was born on `element`. As a patch is applied it joins every change open on that
    /// element or on one holding it; `inLayoutPass` - no patch being applied - it joins every change whose patch
    /// reached the element or what holds it and whose layout has not placed it yet.
    func born(_ member: Member, on element: MountedElement, inLayoutPass: Bool) {
        guard !opened.isEmpty || (inLayoutPass && wantsFrames) else { return }

        let above = Self.mounts(from: element)
        for group in opened where above.contains(group.root) { group.members.insert(member) }
        guard inLayoutPass else { return }

        for group in waiting where group.framesLeft > 0 && above.contains(group.root) {
            if group.touched.contains(element.mount) || element.parent.map({ group.touched.contains($0.mount) }) == true {
                group.members.insert(member)
            }
        }
    }

    /// A layout pass gives `element` a place: what holds it has arranged what a patch said of it.
    func placing(_ element: MountedElement) {
        guard wantsFrames else { return }

        arranged.insert(element.mount)
        if let holder = element.parent { arranged.insert(holder.mount) }
    }

    /// The movement `member` ended as `end` - or, its element released as its exit ended, as that exit did:
    /// every change it was a member of has one fewer to wait for.
    func ended(_ member: Member, as end: End) {
        var end = end
        if end == .detached, case .described(let key) = member, let exit = exits[key.mount] { end = exit }
        for group in opened + waiting where group.members.remove(member) != nil {
            switch end {
            case .rested: break
            case .superseded: group.reasons.append(.superseded)
            case .stopped: group.reasons.append(.stopped)
            case .detached: group.reasons.append(.detached)
            case .limited: group.reasons.append(.limited)
            }
        }
        settle()
    }

    /// The exit of the element `mount` ends as `result`, before the element is released: what its movements
    /// still under way end as. `released` says the release is over.
    func exitEnds(_ mount: UInt64, as result: PresentationOperation.Result) {
        switch result {
        case .finished: exits[mount] = .rested
        case .interrupted: exits[mount] = .superseded
        case .limited: exits[mount] = .limited
        case .cancelled, .detached: exits[mount] = .detached
        }
    }

    func released(_ mount: UInt64) {
        exits[mount] = nil
    }

    /// `element` left by an exit nothing draws - `reason` says why: every change whose patch is being applied over
    /// it hears so, the movement born and ended in one step.
    func refused(_ element: MountedElement, _ reason: PresentationInterruption) {
        guard !opened.isEmpty else { return }

        let above = Self.mounts(from: element)
        for group in opened where above.contains(group.root) { group.reasons.append(reason) }
    }

    /// The render's patch is applied: the changes it opened are answered so, and wait for their members and for
    /// the layout pass - one whose patch reached nothing under its view is settled at once.
    public func close() {
        for group in opened {
            core.answer(group.change.applied, applied: .applied)
            group.framesLeft = group.awaitsNothing ? 0 : Self.layoutWindow
        }
        waiting.append(contentsOf: opened)
        opened.removeAll()
        recent.removeAll(keepingCapacity: true)
        settle()
    }

    /// A display frame ended: what arranged since the last is no change's to wait for any more, and a window
    /// with nothing left to wait for, or as old as it gets, is over.
    public func frameEnded() {
        for group in waiting where group.framesLeft > 0 {
            group.touched.subtract(arranged)
            group.framesLeft = group.awaitsNothing ? 0 : group.framesLeft - 1
            if group.framesLeft == 0 {
                group.touched.removeAll()
                group.states.removeAll()
            }
        }
        arranged.removeAll(keepingCapacity: true)
        settle()
    }

    private func settle() {
        let done = waiting.filter { $0.members.isEmpty && $0.framesLeft == 0 }
        guard !done.isEmpty else { return }

        waiting.removeAll { $0.members.isEmpty && $0.framesLeft == 0 }
        for group in done {
            // The core names each reason once, in the order they are declared.
            core.answer(group.change.settled, settled: group.reasons.isEmpty ? .settled : .interrupted(group.reasons))
        }
    }

    /// The mounts of `element` and of everything holding it.
    private static func mounts(from element: MountedElement) -> Set<UInt64> {
        var above: Set<UInt64> = []
        var each: MountedElement? = element
        while let next = each {
            above.insert(next.mount)
            each = next.parent
        }
        return above
    }
}
