// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// The pointer and a page leaving the screen, as every host takes it.
@MainActor
final class PagePointerTests: XCTestCase {
    /// A page leaving the screen takes the pointer off what of it the pointer stood over - the toolkit tells no exit to
    /// a view gone from under the pointer, and a state following the pointer would stay; a view the pointer left
    /// already hears nothing more.
    func testAPageLeavingTakesThePointerOffWhatItHolds() throws {
        exited = []
        stateUIUseApp(PointerApplication())
        let runtime = HostRuntime(
            clock: StillClock(), reducesMotion: { false }, makeNative: { StillView(id: $0.id) }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()
        // The window shown, as its host shows it: its pages are on the screen.
        _ = WindowPresentation().show(try XCTUnwrap(runtime.tree.root?.windows.first), in: runtime.lifecycle)
        let element = { (id: String) in try XCTUnwrap(runtime.tree.root?.first(id: .manual(id))) }
        let (row, left) = (try element("row"), try element("left"))
        row.hear(.pointer(.pointerEntered, Point(1, 1)), in: runtime)
        left.hear(.pointer(.pointerEntered, Point(1, 1)), in: runtime)
        left.hear(.pointer(.pointerExited, Point(1, 1)), in: runtime)
        for _ in 0..<5 { runtime.pump.turn() }
        exited = []

        try element("push").hear(.tap(run: 1), in: runtime)
        for _ in 0..<5 { runtime.pump.turn() }

        XCTAssertEqual(exited, ["row"], "the row the pointer stood over, and only it")
    }
}

/// The views the pointer was told to leave, in order.
@MainActor private var exited: [String] = []

/// A native half that keeps nothing.
@MainActor
private final class StillView: NativeElement {
    let id: ElementID
    let presentsView = true
    init(id: ElementID) { self.id = id }
    func standingValue(_ property: Prop) -> HostValue? { nil }
    func animates(_ property: Prop) -> Bool { false }
    func applied(changed: Set<Prop>, wasDescribed: Bool) {}
    func presentFrame(_ changed: Set<Prop>) {}
    func arrangeChildren() {}
    func invalidateMeasurements() {}
    func configureLayoutMotion() {}
    func leave() {}
}

private struct PointerPage: View {
    @State private var path: [Int] = []

    var body: some View {
        NavigationStack($path) {
            VStack {
                ZStack { Text("Row") }.onPointerEntered {}.onPointerExited { @MainActor in exited.append("row") }.id("row")
                ZStack { Text("Left") }.onPointerEntered {}.onPointerExited { @MainActor in exited.append("left") }.id("left")
                Text("Push").onTapped { path.append(1) }.id("push")
            }
        } destination: { _ in
            Text("Next")
        }
    }
}

private struct PointerApplication: Application {
    var body: some Scene { WindowGroup { PointerPage() } }
}
