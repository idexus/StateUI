// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A view the tree disables, or one standing in a disabled view, as every host takes it: it hears nothing of the
/// user's hand, a control in it is presented disabled, and the views in a branch enabled again are told so.
@MainActor
final class DisabledBranchTests: XCTestCase {
    func testAViewInADisabledBranchHearsNoHand() throws {
        let runtime = running()
        let inner = try element("inner", in: runtime)

        inner.hear(.tap(run: 1), in: runtime)
        inner.hear(.pointer(.pointerEntered, Point(1, 1)), in: runtime)
        for _ in 0..<5 { runtime.pump.turn() }

        XCTAssertEqual(heard, [], "neither a tap nor the pointer in a disabled branch")
        XCTAssertFalse(inner.isEffectivelyEnabled)
        XCTAssertEqual(inner.presented(.isEnabled), .bool(false), "presented disabled, its own value written nowhere")
        XCTAssertNil(inner.value(.isEnabled), "its own value is what the tree wrote")
        XCTAssertTrue(born.contains(.manual("inner")), "made in the branch, its view was told its isEnabled")
    }

    func testABranchEnabledAgainTellsTheViewsInIt() throws {
        let runtime = running()
        let opener = try element("opener", in: runtime)
        told = []

        opener.hear(.tap(run: 1), in: runtime)
        for _ in 0..<5 { runtime.pump.turn() }
        let inner = try element("inner", in: runtime)

        XCTAssertTrue(inner.isEffectivelyEnabled)
        XCTAssertEqual(inner.presented(.isEnabled), nil, "its own value again: none written")
        XCTAssertTrue(told.contains(.manual("inner")), "the view in the branch heard its enablement turn")

        inner.hear(.tap(run: 1), in: runtime)
        for _ in 0..<5 { runtime.pump.turn() }
        XCTAssertEqual(heard, ["opened", "inner tapped"])
    }

    private func running() -> HostRuntime {
        heard = []
        told = []
        born = []
        stateUIUseApp(BranchApplication())
        let runtime = HostRuntime(
            clock: StillClock(), reducesMotion: { false }, makeNative: { TellingView(id: $0.id) }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()
        return runtime
    }

    private func element(_ id: String, in runtime: HostRuntime) throws -> MountedElement {
        try XCTUnwrap(runtime.tree.root?.first(id: .manual(id)))
    }
}

/// What the views heard of the user's hand, in order.
@MainActor private var heard: [String] = []

/// The views told their `isEnabled` changed after they were made.
@MainActor private var told: [ElementID] = []

/// The views told their `isEnabled` as they were made.
@MainActor private var born: [ElementID] = []

/// A native half that notes each later `isEnabled` it is told.
@MainActor
private final class TellingView: NativeElement {
    let id: ElementID
    let presentsView = true
    init(id: ElementID) { self.id = id }
    func standingValue(_ property: Prop) -> HostValue? { nil }
    func animates(_ property: Prop) -> Bool { false }
    func applied(changed: Set<Prop>, wasDescribed: Bool) {
        if changed.contains(.isEnabled) { if wasDescribed { told.append(id) } else { born.append(id) } }
    }
    func presentFrame(_ changed: Set<Prop>) {}
    func arrangeChildren() {}
    func leave() {}
}

private struct BranchPage: View {
    @State private var open = false

    var body: some View {
        VStack {
            VStack {
                Text("Inner").onTapped { @MainActor in heard.append("inner tapped") }.id("inner")
                    .onPointerEntered { @MainActor in heard.append("inner entered") }
            }
            .isEnabled(open)
            .id("branch")
            Text("Open").onTapped { @MainActor in
                heard.append("opened")
                open = true
            }
            .id("opener")
        }
    }
}

private struct BranchApplication: Application {
    var body: some Scene { WindowGroup { BranchPage() } }
}
