// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A deck of two cards a motion layout places, the second drawn at half its size.
private struct HalvedDeck: View {
    var body: some View {
        VStack {
            MotionLayout([1, 2], parameters: State(wrappedValue: 0.0).projectedValue) { card in
                Text("card \(card)")
            } placements: { _, _ in
                [Placement(Rect(x: 40, y: 40, width: 40, height: 40)),
                 Placement(Rect(x: 90, y: 40, width: 40, height: 40), transform: .scale(0.5))]
            }
        }
    }
}

private struct HalvedDeckApplication: Application {
    var body: some Scene { WindowGroup { HalvedDeck() } }
}

/// Where an element's laid-out rectangle stands in its window, no transform in it (`MountedElement.cornerInWindow`).
@MainActor
final class WindowCornerTests: XCTestCase {
    /// A VIEW ITS LAYOUT'S PROGRAM DRAWS TRANSFORMED stands transformed too: its corner is its layout's with its place
    /// added - never the toolkit's, which the program's scale about the view's middle moves.
    func testACornerTakesNoTransformItsLayoutDrawsItWith() throws {
        HalvedDeckApplication.register()
        let clock = WoundClock()
        let runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()
        let deck = try XCTUnwrap(runtime.tree.root?.first(type: .motionLayout))
        deck.reportFrame([0, 0, 300, 200, 10, 20, 10, 20], in: runtime)
        for time in stride(from: 16.0, through: 64, by: 16) {
            clock.time = time
            runtime.displayCycle.frame(now: time)
            runtime.pump.turn()
        }
        let halved = try XCTUnwrap(deck.children.last)
        XCTAssertEqual(halved.drawnTransform.scaleX, 0.5, accuracy: 0.001, "drawn at half its size by its layout")

        // The toolkit converts the 40-point square at (90, 40) in a deck at (10, 20), halved about its middle.
        let corner = halved.cornerInWindow(
            toolkit: { $0 === halved ? Point(x: 110, y: 70) : $0 === deck ? Point(x: 10, y: 20) : nil },
            place: { $0 === halved ? Point(x: 90, y: 40) : nil },
            scrolled: { _ in Point(x: 0, y: 0) })
        XCTAssertEqual(corner, Point(x: 100, y: 60), "the deck's corner with its place added, no scale in it")
    }

    /// A rectangle moved by a transform of its own, and one in a moved layout, stand where their layouts placed them:
    /// the corner of the layout above, their place in it added and its scroll taken away - never the toolkit's,
    /// which moves with the drawing; one under no transform stands at the toolkit's own.
    func testACornerTakesNoTransform() {
        let tree = Self.tree()
        var moved = HostPatch(id: .manual("moved"), type: .rectangle)
        moved.properties[.translationX] = .number(50)
        var held = HostPatch(id: .manual("held"), type: .vStack)
        held.properties[.scale] = .number(2)
        held.children = .arranged([HostPatch(id: .manual("inner"), type: .rectangle)])
        var root = HostPatch(id: .manual("root"), type: .vStack)
        root.children = .arranged([moved, held, HostPatch(id: .manual("plain"), type: .rectangle)])
        tree.apply(root, complete: true)

        // What a toolkit says: each corner with the drawing's moves in it.
        let toolkit = ["root": Point(x: 0, y: 52), "moved": Point(x: 50, y: 52), "held": Point(x: -20, y: 62),
                       "inner": Point(x: -20, y: 62), "plain": Point(x: 0, y: 92)]
        let place = ["root": Point(x: 0, y: 0), "moved": Point(x: 0, y: 0), "held": Point(x: 0, y: 20),
                     "inner": Point(x: 0, y: 0), "plain": Point(x: 0, y: 40)]
        func corner(_ name: String, rootScrolled: Point = Point(x: 0, y: 0)) -> Point? {
            tree.root?.first(id: .manual(name))?.cornerInWindow(
                toolkit: { toolkit[Self.name($0)] }, place: { place[Self.name($0)] },
                scrolled: { Self.name($0) == "root" ? rootScrolled : Point(x: 0, y: 0) })
        }

        XCTAssertEqual(corner("moved"), Point(x: 0, y: 52), "its own move left out")
        XCTAssertEqual(corner("inner"), Point(x: 0, y: 72), "the layout's size left out")
        XCTAssertEqual(corner("plain"), Point(x: 0, y: 92), "the toolkit's own where nothing is moved")
        XCTAssertEqual(corner("inner", rootScrolled: Point(x: 0, y: 15)), Point(x: 0, y: 57), "the scroll above taken away")
    }

    /// A tree of plain views.
    private static func tree() -> MountedTree {
        let animator = Animator()
        return MountedTree(
            core: CoreLink(),
            intake: PatchIntake(),
            stateChannels: StateChannels(animator: animator),
            describedMotion: DescribedMotion(animator: animator),
            layoutMotion: LayoutMotion(animator: animator, now: { 0 }, reducesMotion: { false }),
            now: { 0 },
            reducesMotion: { false },
            diagnostics: DiagnosticText(tallies: false, inspects: false) { _ in },
            makeNative: { PlainView($0) })
    }

    private static func name(_ element: MountedElement) -> String {
        if case .manual(let name) = element.id { return name }
        return "\(element.id)"
    }
}

/// A view that does nothing of its own.
@MainActor
private final class PlainView: NativeElement {
    func measured(width: Double?, height: Double?) -> HostChildMeasured {
        HostChildMeasured(size: .zero, firstBaseline: nil)
    }
    unowned let element: MountedElement
    let presentsView = true

    init(_ element: MountedElement) { self.element = element }

    func standingValue(_ property: Prop) -> HostValue? { nil }
    func animates(_ property: Prop) -> Bool { false }
    func applied(changed: Set<Prop>, wasDescribed: Bool) {}
    func presentFrame(_ changed: Set<Prop>) {}
    func arrangeChildren() {}
    func orderChildren() {}
    func invalidateMeasurements() {}
    func configureLayoutMotion() {}
    func directionChanged() {}
    func deactivate() {}
}
