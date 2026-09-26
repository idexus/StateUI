// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
#if os(Windows)
import CRT
#endif

/// The mounted tree every Swift runtime shares: patches, drift, leaving and the frame walk.
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
            from: HostBoundary.value(of: standing),
            now: 0,
            reducesMotion: false)
        XCTAssertEqual(tree.stateChannels.count, 1)

        stack.children = .arranged([])
        tree.apply(stack, complete: false)

        XCTAssertEqual(Set(log.left), ["row", "bound"])
        XCTAssertEqual(tree.stateChannels.count, 0, "the last wearer took the channel along")
    }

    /// A row arriving after another of its kind left is mounted anew: the tree keeps nothing an arrangement dropped.
    @MainActor
    func testARowArrivingAfterOneOfItsKindLeftIsMountedAnew() {
        let (tree, log) = Self.tree()
        func layers(_ rows: [String]) -> HostPatch {
            var layers = HostPatch(id: .manual("layers"), type: .zStack)
            layers.children = .arranged(rows.map { HostPatch(id: .manual($0), type: .label) })
            return layers
        }
        tree.apply(layers(["a"]), complete: true)
        let first = tree.root?.children.first

        tree.apply(layers([]), complete: false)
        XCTAssertEqual(log.left, ["a"])

        tree.apply(layers(["b"]), complete: false)
        XCTAssertFalse(tree.root?.children.first === first)
        XCTAssertEqual(tree.root?.children.first?.id, .manual("b"))
    }

    /// While an inspector records, a message applied tells it the host's half on the pass of its generation:
    /// the elements walked, made and kept, and each scene's part by its place in the application.
    @MainActor
    func testAMessageAppliedTellsTheInspectorWhatItCost() throws {
        Scenes.shared.reset()
        Scenes.shared.connected(restoring: [:])
        Scenes.shared.connected(restoring: [:])
        Inspection.start()
        defer {
            Inspection.stop()
            Scenes.shared.reset()
        }
        for generation: Int32 in 1...3 {
            Inspection.begin(road: .build, causes: [])
            Inspection.end(generation: generation, describe: 0, keep: true)
        }

        func patch(_ id: String, _ type: NodeType, _ children: HostChildrenUpdate = .unchanged) -> HostPatch {
            var patch = HostPatch(id: .manual(id), type: type)
            patch.children = children
            return patch
        }
        func list(_ rows: [String]) -> HostPatch {
            patch("list", .zStack, .arranged(rows.map { patch($0, .label) }))
        }
        func secondScene(_ rows: [String]) -> HostPatch {
            patch("application", .application, .changed([patch("2", .scene, .changed([list(rows)]))]))
        }

        let (tree, _) = Self.tree()
        let whole = patch("application", .application, .arranged([
            patch("1", .scene, .arranged([patch("a", .label)])),
            patch("2", .scene, .arranged([list(["r1"])])),
        ]))
        tree.intake.take(whole, generation: 1) { tree.apply($0, complete: true) }
        tree.intake.take(secondScene([]), generation: 2) { tree.apply($0, complete: false) }
        tree.intake.take(secondScene(["r2"]), generation: 3) { tree.apply($0, complete: false) }

        let hosts = try Inspection.passes.map { try XCTUnwrap($0.host, "no host half for #\($0.generation)") }
        XCTAssertEqual(
            hosts.map { [$0.nodes, $0.made, $0.kept] }, [[6, 6, 0], [3, 0, 3], [4, 1, 3]])
        XCTAssertTrue(hosts.allSatisfy { $0.apply > 0 })
        XCTAssertEqual(hosts.map { $0.scenes.map { $0 > 0 } }, [[true, true], [false, true], [false, true]])
    }

    /// An element whose direction turns has every layout under it that inherits the direction arrange its
    /// children again; one that says its own direction, and what stands under it, is left as it is.
    @MainActor
    func testADirectionTurnedArrangesTheLayoutsThatInheritIt() {
        let (tree, log) = Self.tree()
        var own = Self.stack("own", ["b"])
        own.properties = [.layoutDirection: .enumeration(LayoutDirection.leftToRight.rawValue)]
        var outer = HostPatch(id: .manual("outer"), type: .vStack)
        outer.children = .arranged([Self.stack("inner", ["a"]), own])
        tree.apply(outer, complete: true)
        log.arranged.removeAll()

        var turned = HostPatch(id: .manual("outer"), type: .vStack)
        turned.properties = [.layoutDirection: .enumeration(LayoutDirection.rightToLeft.rawValue)]
        tree.apply(turned, complete: false)

        XCTAssertEqual(tree.root?.children.map(\.layoutDirection), [.rightToLeft, .leftToRight])
        XCTAssertEqual(log.arranged, ["inner"])
    }

    /// The language's direction turning lays the whole tree out again, and only a turn does.
    @MainActor
    func testTheLanguagesDirectionTurningArrangesEveryLayout() {
        let (tree, log) = Self.tree()
        let locale = StandardEnvironment.locale
        defer { locale.layoutDirection = .leftToRight }
        tree.apply(Self.stack("stack", ["a"]), complete: true)
        tree.followTheLanguagesDirection()
        log.arranged.removeAll()

        tree.followTheLanguagesDirection()
        XCTAssertEqual(log.arranged, [], "the language did not turn")

        locale.layoutDirection = .rightToLeft
        tree.followTheLanguagesDirection()
        XCTAssertEqual(tree.root?.layoutDirection, .rightToLeft)
        XCTAssertEqual(log.arranged, ["stack"])
    }

    /// With the tally on, a message that stands alone writes the running totals; one right behind it writes
    /// nothing, and the next after a quiet spell writes them all again.
    @MainActor
    func testTheTallyIsWrittenAfterAMessageThatStandsAlone() {
        var written: [String] = []
        var clock = 0.0
        let (tree, _) = Self.tree(
            diagnostics: DiagnosticText(tallies: true, inspects: false) { written.append($0) }, now: { clock })

        tree.apply(Self.stack("stack", ["a", "b"]), complete: true)
        tree.apply(Self.stack("stack", ["a", "b", "c"]), complete: false)
        clock = 400
        tree.apply(Self.stack("stack", ["a"]), complete: false)

        XCTAssertEqual(written.count, 2, written.joined())
        XCTAssertTrue(written[0].hasPrefix("StateUI tally: applies 1  nodes 3  made 3  kept 0  renders "), written[0])
        XCTAssertTrue(written[1].hasPrefix("StateUI tally: applies 3  nodes 9  made 4  kept 5  renders "), written[1])
        XCTAssertTrue(written[1].hasSuffix(" ms total\n"), written[1])
    }

    /// With the passes asked for, the tree starts the inspector's recording, and each message applied writes
    /// the pass it ended as text.
    @MainActor
    func testEveryPassIsWrittenAsTextWhenAskedFor() {
        defer {
            Inspection.logging = false
            Inspection.stop()
        }
        var written: [String] = []
        let (tree, _) = Self.tree(diagnostics: DiagnosticText(tallies: false, inspects: true) { written.append($0) })
        XCTAssertTrue(Inspection.recording, "the tree starts the recording itself")

        Inspection.begin(road: .build, causes: ["count"])
        Inspection.end(generation: 1, describe: 12, keep: true)
        tree.intake.take(Self.stack("stack", ["a"]), generation: 1) { tree.apply($0, complete: true) }

        XCTAssertEqual(written.count, 1)
        XCTAssertTrue(written.first?.contains(" build ") ?? false, written.joined())
        XCTAssertTrue(written.first?.contains(" for count · Swift 12 µs · host ") ?? false, written.joined())
        XCTAssertTrue(written.first?.contains(" 2 nodes, 2 made, 0 kept") ?? false, written.joined())
    }

    /// The switches are read off the process's environment: `1` turns one on, anything else leaves it off.
    func testTheSwitchesAreReadOffTheProcesssEnvironment() {
        defer { Self.setEnvironment("STATEUI_TALLY", nil) }

        Self.setEnvironment("STATEUI_TALLY", "1")
        XCTAssertTrue(DiagnosticText.environment.tallies)

        Self.setEnvironment("STATEUI_TALLY", "0")
        XCTAssertFalse(DiagnosticText.environment.tallies)
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

    /// A grid's and a ZStack's children stand in the order they are drawn: by `zIndex`, ties in the order
    /// written. A sparse change restacks them; a stack's children never overlap and keep the order written.
    @MainActor
    func testALayeredLayoutsChildrenStandInTheOrderTheyAreDrawn() {
        func layered(_ type: NodeType, _ children: [HostPatch]) -> HostPatch {
            var layout = HostPatch(id: .manual("layout"), type: type)
            layout.children = .arranged(children)
            return layout
        }
        let children = [("a", 0.0), ("b", 2), ("c", 1), ("d", 0)].map(Self.layer)

        for type in [NodeType.grid, .zStack] {
            let (tree, _) = Self.tree()
            tree.apply(layered(type, children), complete: true)
            XCTAssertEqual(Self.names(tree.root?.children), ["a", "d", "c", "b"], "\(type): ties in the order written")

            var sparse = HostPatch(id: .manual("layout"), type: type)
            sparse.children = .changed([Self.layer("b", -1)])
            tree.apply(sparse, complete: false)
            XCTAssertEqual(Self.names(tree.root?.children), ["b", "a", "d", "c"], "\(type)")
        }

        let (tree, _) = Self.tree()
        tree.apply(layered(.vStack, children), complete: true)
        XCTAssertEqual(Self.names(tree.root?.children), ["a", "b", "c", "d"], "a stack keeps the order written")
    }

    /// The area a child names reaches its ZStack's arithmetic as it was written, and a child naming none
    /// has none.
    @MainActor
    func testAChildsAreaReachesItsLayout() {
        let (tree, _) = Self.tree()
        var half = HostPatch(id: .manual("half"), type: .label)
        half.properties[.area] = Area.proportional(0.5, 0, 0.5, 1).propValue
        var layers = HostPatch(id: .manual("layers"), type: .zStack)
        layers.children = .arranged([half, HostPatch(id: .manual("whole"), type: .label)])
        tree.apply(layers, complete: true)

        XCTAssertEqual(tree.root?.children.first?.layoutValues.area, .proportional(0.5, 0, 0.5, 1))
        XCTAssertNil(tree.root?.children.last?.layoutValues.area)
    }

    /// A bound `zIndex` restacks its grid in the frame that moved it, and arranges it once; a frame that
    /// moves nothing leaves the order and the grid alone.
    @MainActor
    func testABoundZIndexRestacksItsLayoutInAFrame() {
        let (tree, log) = Self.tree()
        var raised = HostPatch(id: .manual("raised"), type: .label)
        raised.driven = .replace([.zIndex: HostStateBinding(state: 700, mode: .out, kind: .plain)])
        var grid = HostPatch(id: .manual("grid"), type: .grid)
        grid.children = .arranged([raised, Self.layer("still", 1)])
        tree.apply(grid, complete: true)
        log.arranged.removeAll()

        tree.present(states: [700: .lanes([5])], properties: [:])
        XCTAssertEqual(Self.names(tree.root?.children), ["still", "raised"])
        XCTAssertEqual(log.arranged, ["raised", "grid"])

        log.arranged.removeAll()
        tree.present(states: [700: .lanes([5])], properties: [:])
        XCTAssertEqual(log.arranged, ["raised"], "the order did not move")
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

    /// What assistive technology meets of an element is its words and its presence: left out with its children
    /// before hidden, hidden before met, and nothing said where the element says nothing.
    @MainActor
    func testAnElementsAccessibilityWordsAreItsOwn() {
        let (tree, _) = Self.tree()
        func label(_ id: String, _ properties: [Prop: HostValue]) -> HostPatch {
            var label = HostPatch(id: .manual(id), type: .label)
            label.properties = properties
            return label
        }
        var root = HostPatch(id: .manual("root"), type: .vStack)
        root.children = .arranged([
            label("said", [
                .accessibilityIdentifier: .string("greeting"), .accessibilityLabel: .string("Hello"),
                .accessibilityHint: .string("Says hello"), .accessibilityHeadingLevel: .enumeration(2),
                .isAccessibilityHidden: .bool(false),
            ]),
            label("both", [.isAccessibilityHidden: .bool(true), .automationExcludedWithChildren: .bool(true)]),
            label("hidden", [.isAccessibilityHidden: .bool(true)]),
            label("silent", [:]),
        ])
        tree.apply(root, complete: true)
        func words(_ id: String) -> AccessibilityWords? { tree.root?.first(id: .manual(id))?.accessibilityWords }

        XCTAssertEqual(words("said"), AccessibilityWords(
            identifier: "greeting", label: "Hello", hint: "Says hello", headingLevel: 2, presence: .met))
        XCTAssertEqual(words("both")?.presence, .hiddenWithChildren)
        XCTAssertEqual(words("hidden")?.presence, .hidden)
        XCTAssertEqual(words("silent"), AccessibilityWords(
            identifier: nil, label: nil, hint: nil, headingLevel: 0, presence: nil))
    }

    /// An element is drawn moved, turned and scaled as it says: `scale` on top of each axis's own, about its middle
    /// where it names no pivot.
    @MainActor
    func testAnElementIsDrawnOverItsPlaceAsItSays() {
        let (tree, _) = Self.tree()
        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties = [.scale: .number(2), .scaleX: .number(1.5), .translationY: .number(8), .rotation: .number(30)]
        var root = HostPatch(id: .manual("root"), type: .vStack)
        root.children = .arranged([label, HostPatch(id: .manual("plain"), type: .label)])
        tree.apply(root, complete: true)

        let drawn = tree.root?.first(id: .manual("label"))?.drawingTransform
        XCTAssertEqual(drawn?.scaleX, 3)
        XCTAssertEqual(drawn?.scaleY, 2)
        XCTAssertEqual(drawn?.translationY, 8)
        XCTAssertEqual(drawn?.rotation, 30)
        XCTAssertEqual(drawn?.pivotX, 0.5)
        XCTAssertEqual(tree.root?.first(id: .manual("plain"))?.drawingTransform, .identity)
    }

    /// A label's spans are runs of its words, each in its own case else the label's, with its own look; a label
    /// with no spans has no runs.
    @MainActor
    func testALabelsSpansAreRunsOfItsWords() {
        let (tree, _) = Self.tree()
        func span(_ id: String, _ properties: [Prop: HostValue]) -> HostPatch {
            var span = HostPatch(id: .manual(id), type: .span)
            span.properties = properties
            return span
        }
        var spans = HostPatch(id: .manual("spans"), type: .spans)
        spans.children = .arranged([
            span("one", [.text: .string("Big "), .fontSize: .number(20)]),
            span("two", [.text: .string("Small"), .textCase: .enumeration(TextCase.lowercase.rawValue)]),
        ])
        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties = [.textCase: .enumeration(TextCase.uppercase.rawValue)]
        label.children = .arranged([spans])
        var root = HostPatch(id: .manual("root"), type: .vStack)
        root.children = .arranged([label, HostPatch(id: .manual("plain"), type: .label)])
        tree.apply(root, complete: true)

        let runs = tree.root?.first(id: .manual("label"))?.textRuns
        XCTAssertEqual(runs?.map(\.text), ["BIG ", "small"], "each in its own case, else the label's")
        XCTAssertEqual(runs?.first?.look.size, 20)
        XCTAssertNil(tree.root?.first(id: .manual("plain"))?.textRuns)
    }

    /// A run's look stands over its label's: where the run says nothing, the label's says it.
    func testARunsLookStandsOverItsLabels() {
        var run = TextLook()
        run.size = 20
        var label = TextLook()
        label.size = 12
        label.family = "Serif"
        label.letterSpacing = 1

        let drawn = run.over(label)
        XCTAssertEqual(drawn.size, 20)
        XCTAssertEqual(drawn.family, "Serif")
        XCTAssertEqual(drawn.letterSpacing, 1)
    }

    /// A direction is inherited: a view left at `.inherited` takes its parent's, one that states its own
    /// keeps it under any parent, and the root takes the language's, as the host reported the locale.
    @MainActor
    func testALayoutDirectionIsInheritedFromTheParentAndAtTheRootFromTheLocale() {
        defer { StandardEnvironment.locale.layoutDirection = .leftToRight }
        let (tree, _) = Self.tree()
        var outer = Self.stack("outer", [])
        outer.properties[.layoutDirection] = LayoutDirection.rightToLeft.propValue
        var stated = HostPatch(id: .manual("stated"), type: .hStack)
        stated.properties[.layoutDirection] = LayoutDirection.leftToRight.propValue
        outer.children = .arranged([HostPatch(id: .manual("inheriting"), type: .label), stated])
        var root = HostPatch(id: .manual("root"), type: .vStack)
        root.children = .arranged([outer, HostPatch(id: .manual("plain"), type: .label)])
        tree.apply(root, complete: true)

        let rootElement = tree.root
        let outerElement = rootElement?.children.first
        XCTAssertEqual(outerElement?.layoutDirection, .rightToLeft)
        XCTAssertEqual(outerElement?.children.first?.layoutDirection, .rightToLeft, "inherited from its parent")
        XCTAssertEqual(outerElement?.children.last?.layoutDirection, .leftToRight, "its own, under any parent")
        XCTAssertEqual(rootElement?.children.last?.layoutDirection, .leftToRight, "the language's at the root")

        StandardEnvironment.locale.layoutDirection = .rightToLeft
        XCTAssertEqual(rootElement?.children.last?.layoutDirection, .rightToLeft, "a language written right to left")
    }

    /// Every write a frame's walk makes is the program's: a native callback it sets off reports nothing.
    @MainActor
    func testAFramesWritesAreTheProgramsOwn() throws {
        let (tree, log) = Self.tree()
        tree.apply(Self.stack("stack", ["a"]), complete: true)
        let mount = try XCTUnwrap(tree.root?.children.first?.mount)

        tree.present(states: [:], properties: [mount: [.opacity]])

        XCTAssertEqual(log.presentedWriting, [true])
    }

    // MARK: - A tree over a recording native half

    @MainActor
    private static func tree(
        viewless: Set<String> = [],
        diagnostics: DiagnosticText = DiagnosticText(tallies: false, inspects: false) { _ in },
        now: @escaping () -> Double = { 0 }
    ) -> (MountedTree, NativeLog) {
        let animator = Animator()
        let log = NativeLog()
        let tree = MountedTree(
            core: CoreLink(),
            intake: PatchIntake(),
            stateChannels: StateChannels(animator: animator),
            describedMotion: DescribedMotion(animator: animator),
            layoutMotion: LayoutMotion(animator: animator, now: { 0 }, reducesMotion: { false }),
            now: now,
            reducesMotion: { false },
            diagnostics: diagnostics,
            makeNative: { RecordingNative($0, log: log, viewless: viewless) })
        return (tree, log)
    }

    private static func stack(_ id: String, _ children: [String]) -> HostPatch {
        var stack = HostPatch(id: .manual(id), type: .vStack)
        stack.children = .arranged(children.map { HostPatch(id: .manual($0), type: .label) })
        return stack
    }

    /// Sets `name` in this process's environment, or removes it for nil.
    private static func setEnvironment(_ name: String, _ value: String?) {
        #if os(Windows)
        _ = _putenv_s(name, value ?? "")
        #else
        if let value { setenv(name, value, 1) } else { unsetenv(name) }
        #endif
    }

    private static func layer(_ id: String, _ zIndex: Double) -> HostPatch {
        var label = HostPatch(id: .manual(id), type: .label)
        label.properties[.zIndex] = .number(zIndex)
        return label
    }

    @MainActor
    private static func names(_ elements: [MountedElement]?) -> [String] {
        (elements ?? []).map { element in
            if case .manual(let name) = element.id { return name }
            return "\(element.id)"
        }
    }
}

/// What the native halves heard, by element key.
@MainActor
private final class NativeLog {
    var applied: [String] = []
    var arranged: [String] = []
    var left: [String] = []
    var presentedWriting: [Bool] = []
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
    func standingValue(_ property: Prop) -> HostValue? { nil }
    func animates(_ property: Prop) -> Bool { false }
    func applied(changed: Set<Prop>, wasDescribed: Bool) { log.applied.append(name) }
    func presentFrame(_ changed: Set<Prop>) -> FrameImpact {
        log.presentedWriting.append(ProgramWrite.isWriting)
        return FrameImpact(content: true, arrangement: changed.contains(.width))
    }
    func arrangeChildren() { log.arranged.append(name) }
    func leave() { log.left.append(name) }
}
