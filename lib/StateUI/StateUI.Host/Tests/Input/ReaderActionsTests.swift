// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// What a screen reader does to a view, as every host hands it on: an action the view offers, by its words, and a
/// step of a view hearing steps - nothing else, and nothing in a disabled branch.
@MainActor
final class ReaderActionsTests: XCTestCase {
    func testAReadersActionAndStepReachTheViewOfferingThem() throws {
        let runtime = running()
        let rating = try element("rating", in: runtime)

        XCTAssertEqual(rating.accessibilityWords.actions, ["Clear", "Fill"], "in the order written")
        XCTAssertEqual(rating.accessibilityWords.presence, .met, "a view offering actions is met")
        XCTAssertTrue(rating.hear(.accessibilityAction("Fill"), in: runtime))
        XCTAssertFalse(rating.hear(.accessibilityAction("Share"), in: runtime), "an action it does not offer")
        XCTAssertTrue(rating.hear(.accessibilityAdjustment(.decrement), in: runtime))
        for _ in 0..<5 { runtime.pump.turn() }

        XCTAssertEqual(said, ["Fill", "decrement"])
    }

    func testAViewOfferingNothingOrDisabledTakesNothing() throws {
        let runtime = running()
        let (plain, off) = (try element("plain", in: runtime), try element("off", in: runtime))

        XCTAssertFalse(plain.hear(.accessibilityAction("Clear"), in: runtime), "a view offering no action")
        XCTAssertFalse(plain.hear(.accessibilityAdjustment(.increment), in: runtime), "a view hearing no step")
        XCTAssertFalse(off.hear(.accessibilityAction("Clear"), in: runtime), "an action in a disabled branch")
        XCTAssertFalse(off.hear(.accessibilityAdjustment(.increment), in: runtime), "a step in a disabled branch")
        for _ in 0..<5 { runtime.pump.turn() }

        XCTAssertEqual(said, [])
    }

    private func running() -> HostRuntime {
        said = []
        stateUIUseApp(ReaderApplication())
        let runtime = HostRuntime(
            clock: StillClock(), reducesMotion: { false }, makeNative: { ReaderView(id: $0.id) }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()
        return runtime
    }

    private func element(_ id: String, in runtime: HostRuntime) throws -> MountedElement {
        try XCTUnwrap(runtime.tree.root?.first(id: .manual(id)))
    }
}

/// What the views were told a reader did, in order.
@MainActor private var said: [String] = []

/// A native half that keeps nothing.
@MainActor
private final class ReaderView: NativeElement {
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

private struct ReaderPage: View {
    var body: some View {
        VStack {
            HStack { Text("★") }
                .accessibilityRole(.adjustable)
                .onAccessibilityAdjusted { @MainActor step in said.append("\(step)") }
                .accessibilityAction("Clear") { @MainActor in said.append("Clear") }
                .accessibilityAction("Fill") { @MainActor in said.append("Fill") }
                .id("rating")
            Text("Plain").id("plain")
            VStack {
                Text("Off")
                    .onAccessibilityAdjusted { @MainActor _ in said.append("off stepped") }
                    .accessibilityAction("Clear") { @MainActor in said.append("off cleared") }
                    .id("off")
            }
            .isEnabled(false)
        }
    }
}

private struct ReaderApplication: Application {
    var body: some Scene { WindowGroup { ReaderPage() } }
}
