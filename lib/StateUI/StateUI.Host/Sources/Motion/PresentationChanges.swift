// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The presentation changes a tree's renders carry. Each watches the movements born under the view it aims at
/// while its render is applied, answers that it was applied, and answers how they ended once the last has.
/// Design: docs/design/host/motion.md#a-change-and-what-it-started
@_spi(Host) @MainActor public final class PresentationChanges {
    /// How a movement a change watches ended.
    public enum End: Equatable, Sendable {
        /// At rest where it was sent.
        case rested
        /// Sent elsewhere by a later write.
        case superseded
        /// Its view left.
        case detached
    }

    private final class Group {
        let change: HostPresentationChange
        let root: UInt64
        var members: Set<DescribedKey> = []
        var reasons: [PresentationInterruption] = []

        init(_ change: HostPresentationChange, root: UInt64) {
            self.change = change
            self.root = root
        }
    }

    private let core: CoreLink

    /// The groups whose render is being applied: what is born now joins them.
    private var opened: [Group] = []

    /// The groups waiting for their members to end, in the order made.
    private var waiting: [Group] = []

    /// Changes answered through `core`.
    public init(core: CoreLink) {
        self.core = core
    }

    /// How many changes wait for a movement to end.
    public var waitingCount: Int { waiting.count }

    /// A render brings `changes`, before its patch is applied to `tree`: each opens on the view it aims at, and
    /// one nothing shows is answered at once.
    public func begin(_ changes: [HostPresentationChange], in tree: MountedTree) {
        for change in changes {
            guard let element = tree.root?.element(at: change.place), element.lifecycle == .active else {
                core.answer(change.applied, applied: .notPresented)
                core.answer(change.settled, settled: .notPresented)
                continue
            }
            opened.append(Group(change, root: element.mount))
        }
    }

    /// A described motion of `key` was born on `element`: it joins every change opened on that element or on one
    /// holding it.
    func born(_ key: DescribedKey, on element: MountedElement) {
        guard !opened.isEmpty else { return }

        var above: Set<UInt64> = []
        var each: MountedElement? = element
        while let next = each {
            above.insert(next.mount)
            each = next.parent
        }
        for group in opened where above.contains(group.root) { group.members.insert(key) }
    }

    /// The described motion of `key` ended as `end`: every change it was a member of has one movement fewer to
    /// wait for, and one whose last it was is answered.
    func ended(_ key: DescribedKey, as end: End) {
        for group in opened + waiting where group.members.remove(key) != nil {
            switch end {
            case .rested: break
            case .superseded: group.reasons.append(.superseded)
            case .detached: group.reasons.append(.detached)
            }
        }
        settle()
    }

    /// The render's patch is applied: the changes it opened are answered so, and wait for their members - one
    /// with none is settled at once.
    public func close() {
        for group in opened { core.answer(group.change.applied, applied: .applied) }
        waiting.append(contentsOf: opened)
        opened.removeAll()
        settle()
    }

    private func settle() {
        let done = waiting.filter(\.members.isEmpty)
        waiting.removeAll { $0.members.isEmpty }
        for group in done {
            // The core names each reason once, in the order they are declared.
            core.answer(group.change.settled, settled: group.reasons.isEmpty ? .settled : .interrupted(group.reasons))
        }
    }
}
