// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// The mounted tree every Swift runtime shares: patches, drift, leaving, recycling and the frame walk.
final class MountedTreeTests: XCTestCase {
    /// An arranged patch mounts every child in order, each with its native half applied once.
    @MainActor
    func testAPatchMountsItsChildrenInOrder() {
        let (tree, log) = Self.tree()
        tree.apply(Self.stack("stack", ["a", "b", "c"]), complete: true)

        XCTAssertEqual(tree.root?.children.map(\.id), [.manual("a"), .manual("b"), .manual("c")])
        XCTAssertEqual(log.applied.filter { $0 == "a" }.count, 1)
        XCTAssertEqual(log.applied.last, "stack", "a parent is presented after its children")
    }

    /// A sparse message naming a child the element does not hold is drift, and mounts nothing.
    @MainActor
    func testASparseMessageNamingAStrangerDrifts() {
        let (tree, _) = Self.tree()
        tree.apply(Self.stack("stack", ["a"]), complete: true)

        var sparse = HostPatch(id: .manual("stack"), type: .vStack)
        sparse.children = .changed([HostPatch(id: .manual("stranger"), type: .label)])
        tree.intake.take(sparse, generation: 2) { tree.apply($0, complete: false) }

        XCTAssertEqual(tree.root?.children.map(\.id), [.manual("a")])
        XCTAssertTrue(tree.intake.lastDrift?.contains("stranger") ?? false)
        XCTAssertEqual(tree.intake.baseline, 0, "a drifted message claims no generation")
    }

    /// A child of another type sent without `replace` is drift too; with `replace` it is mounted anew.
    @MainActor
    func testAChildOfAnotherTypeIsDriftUnlessReplaced() {
        let (tree, _) = Self.tree()
        tree.apply(Self.stack("stack", ["a"]), complete: true)
        let first = tree.root?.children.first

        var sparse = HostPatch(id: .manual("stack"), type: .vStack)
        sparse.children = .changed([HostPatch(id: .manual("a"), type: .button)])
        tree.intake.take(sparse, generation: 2) { tree.apply($0, complete: false) }
        XCTAssertTrue(tree.root?.children.first === first)
        XCTAssertNotNil(tree.intake.lastDrift)

        var replacing = HostPatch(id: .manual("a"), type: .button)
        replacing.replace = true
        sparse.children = .changed([replacing])
        tree.intake.take(sparse, generation: 3) { tree.apply($0, complete: false) }
        XCTAssertEqual(tree.root?.children.first?.type, .button)
        XCTAssertEqual(tree.intake.baseline, 3)
    }

    /// An element that leaves takes everything under it along, native halves and worn states included.
    @MainActor
    func testALeavingElementDetachesItsSubtree() {
        let (tree, log) = Self.tree()
        var row = HostPatch(id: .manual("row"), type: .hStack)
        var bound = HostPatch(id: .manual("bound"), type: .slider)
        bound.driven = .replace([.value: HostStateBinding(state: 700, mode: .inOut, kind: .property)])
        row.children = .arranged([bound])
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged([row])
        tree.apply(stack, complete: true)
        let standing = HostJourney(value: [0], destination: [0], velocity: [0], motion: .none, completion: nil, stopped: 0)
        _ = tree.stateChannels.presentedValue(
            for: HostStateBinding(state: 700, mode: .inOut, kind: .property),
            from: StateUIHost.value(of: standing),
            now: 0,
            reducesMotion: false)
        XCTAssertEqual(tree.stateChannels.count, 1)

        stack.children = .arranged([])
        tree.apply(stack, complete: false)

        XCTAssertEqual(Set(log.left), ["row", "bound"])
        XCTAssertEqual(tree.stateChannels.count, 0, "the last wearer took the channel along")
    }

    /// A recycling layout keeps a dropped row and gives it to the next row of the same shape.
    @MainActor
    func testARecyclingLayoutAdoptsAKeptRowOfTheSameShape() {
        let (tree, log) = Self.tree()
        func list(_ rows: [String]) -> HostPatch {
            var list = HostPatch(id: .manual("list"), type: .absoluteLayout)
            list.recycles = true
            list.children = .arranged(rows.map { id in
                var row = HostPatch(id: .manual(id), type: .label)
                row.shape = 7
                row.properties = [.text: .string(id)]
                return row
            })
            return list
        }
        tree.apply(list(["a"]), complete: true)
        let kept = tree.root?.children.first

        tree.apply(list([]), complete: false)
        XCTAssertTrue(tree.root?.recycledChildren.first === kept)
        XCTAssertEqual(log.recycled, ["a"])

        tree.apply(list(["b"]), complete: false)
        XCTAssertTrue(tree.root?.children.first === kept, "the kept row is adopted")
        XCTAssertEqual(kept?.id, .manual("b"))
        XCTAssertEqual(kept?.string(.text), "b")
        XCTAssertEqual(log.adopted, ["b"])
        XCTAssertTrue(log.left.isEmpty, "a kept row does not leave")
    }

    /// A frame arranges a parent once when a child's place changed; an element without a view passes it up.
    @MainActor
    func testAFrameArrangesTheParentThatPlacesAChangedChild() {
        let (tree, log) = Self.tree(viewless: ["slot"])
        var child = HostPatch(id: .manual("child"), type: .label)
        child.properties = [.width: .number(10)]
        var slot = HostPatch(id: .manual("slot"), type: .content)
        slot.children = .arranged([child])
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged([slot])
        tree.apply(stack, complete: true)
        log.arranged.removeAll()

        let childMount = tree.root!.children[0].children[0].mount
        tree.present(states: [:], properties: [childMount: [.width]])

        XCTAssertEqual(log.arranged, ["child", "slot", "stack"], "the slot has no view; its parent places the child too")
    }

    /// Each element's `created` handler is taken once, in tree order; a window raises its own.
    @MainActor
    func testCreatedHandlersAreTakenOnceInTreeOrder() {
        let (tree, _) = Self.tree()
        var first = HostPatch(id: .manual("first"), type: .label)
        first.events = .replace([.created: 11])
        var window = HostPatch(id: .manual("window"), type: .window)
        window.events = .replace([.created: 12])
        var second = HostPatch(id: .manual("second"), type: .label)
        second.events = .replace([.created: 13])
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged([first, window, second])
        tree.apply(stack, complete: true)

        XCTAssertEqual(tree.root?.takeCreatedHandlers(), [11, 13])
        XCTAssertEqual(tree.root?.takeCreatedHandlers(), [])
    }

    /// A radio button's peers are its group's in the whole tree, or every radio button beside it where it
    /// names none.
    @MainActor
    func testARadioButtonsPeersAreItsGroupOrItsSiblings() {
        let (tree, _) = Self.tree()
        func radio(_ id: String, group: String?) -> HostPatch {
            var radio = HostPatch(id: .manual(id), type: .radioButton)
            if let group { radio.properties = [.groupName: .name(group)] }
            return radio
        }
        var left = HostPatch(id: .manual("left"), type: .vStack)
        left.children = .arranged([radio("s", group: "size"), radio("x", group: nil), radio("y", group: nil)])
        var right = HostPatch(id: .manual("right"), type: .vStack)
        right.children = .arranged([radio("m", group: "size"), radio("red", group: "colour")])
        var root = HostPatch(id: .manual("root"), type: .hStack)
        root.children = .arranged([left, right])
        tree.apply(root, complete: true)

        func peers(_ id: String) -> [String] {
            (tree.root?.first(id: .manual(id))?.radioPeers ?? []).map { "\($0.id)" }
        }
        XCTAssertEqual(peers("s"), ["\(ElementId.manual("m"))"])
        XCTAssertEqual(peers("x"), ["\(ElementId.manual("s"))", "\(ElementId.manual("y"))"], "every radio beside it")
        XCTAssertEqual(peers("red"), [])
    }

    // MARK: - A tree over a recording native half

    @MainActor
    private static func tree(viewless: Set<String> = []) -> (MountedTree, NativeLog) {
        let animator = Animator()
        let log = NativeLog()
        let tree = MountedTree(
            core: CoreLink(),
            intake: PatchIntake(),
            stateChannels: StateChannels(animator: animator),
            describedMotion: DescribedMotion(animator: animator),
            layoutMotion: LayoutMotion(animator: animator, now: { 0 }, reducesMotion: { false }),
            now: { 0 },
            reducesMotion: { false },
            makeNative: { RecordingNative($0, log: log, viewless: viewless) })
        return (tree, log)
    }

    private static func stack(_ id: String, _ children: [String]) -> HostPatch {
        var stack = HostPatch(id: .manual(id), type: .vStack)
        stack.children = .arranged(children.map { HostPatch(id: .manual($0), type: .label) })
        return stack
    }
}

/// What the native halves heard, by element key.
@MainActor
private final class NativeLog {
    var applied: [String] = []
    var arranged: [String] = []
    var left: [String] = []
    var recycled: [String] = []
    var adopted: [String] = []
}

/// A native half that records what the tree asks of it.
@MainActor
private final class RecordingNative: NativeElement {
    unowned let element: MountedElement
    let log: NativeLog
    let presentsView: Bool

    init(_ element: MountedElement, log: NativeLog, viewless: Set<String>) {
        self.element = element
        self.log = log
        presentsView = !viewless.contains(Self.name(element.id))
    }

    private var name: String { Self.name(element.id) }

    private static func name(_ id: ElementId) -> String {
        if case .manual(let name) = id { return name }
        return "\(id)"
    }

    func willApply() {}
    func adopted() { log.adopted.append(name) }
    func standingValue(_ property: Prop) -> HostValue? { nil }
    func animates(_ property: Prop) -> Bool { false }
    func applied(changed: Set<Prop>, wasDescribed: Bool) { log.applied.append(name) }
    func presentFrame(_ changed: Set<Prop>) -> FrameImpact {
        FrameImpact(content: true, arrangement: changed.contains(.width))
    }
    func arrangeChildren() { log.arranged.append(name) }
    func letGo() {}
    func leave() { log.left.append(name) }
    func setRecycled(_ recycled: Bool) { if recycled { log.recycled.append(name) } }
}
