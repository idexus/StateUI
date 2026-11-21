// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Whether the application below shows its numbered line.
@MainActor private let shown = State(wrappedValue: true)

/// A line of a numbered identity in a stack, coming and going by a transition.
private struct Line: View {
    var body: some View {
        VStack {
            Text("stands")
            if shown.wrappedValue {
                Text("comes")
                    .transition(Transition(enter: .translation(y: 40), exit: .opacity))
                    .motion(.eased(.milliseconds(200), curve: .linear))
                    .id(7)
            }
        }
    }
}

private struct LineApplication: Application {
    var body: some Scene { WindowGroup { Line() } }
}

/// The core and the host layer together, for a view of an identity only the core knows.
@MainActor
final class ReturningViewTests: XCTestCase {
    /// The first stack at or under `element`: the one holding the line.
    private static func stack(_ element: MountedElement) -> MountedElement? {
        element.type == .vStack ? element : element.children.lazy.compactMap(stack).first
    }

    /// A VIEW OF A NUMBERED IDENTITY WRITTEN AGAIN AS IT LEAVES TAKES OVER FROM THE ONE LEAVING: the core's render
    /// names the one that left, the pump hands the tree its table, and the new element - a number of its own -
    /// is known by that id as it is made.
    func testAViewOfANumberedIdentityComesBackAsTheOneLeaving() throws {
        shown.wrappedValue = true
        LineApplication.register()
        let runtime = HostRuntime(clock: StillClock(), reducesMotion: { false }, makeNative: { _ in
            let view = NoView()
            view.keepsExits = true
            return view
        }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()
        let holder = try XCTUnwrap(runtime.tree.root.flatMap(Self.stack))
        let leaving = try XCTUnwrap(holder.children.last)
        XCTAssertEqual(leaving.returnID, leaving.id, "a first life is known by its own id")

        shown.wrappedValue = false
        runtime.pump.turn()
        XCTAssertEqual(leaving.lifecycle, .exiting, "kept as it leaves")

        shown.wrappedValue = true
        runtime.pump.turn()
        let back = try XCTUnwrap(holder.children.last)
        XCTAssertFalse(back === leaving, "another element")
        XCTAssertNotEqual(back.id, leaving.id, "under a number of its own")
        XCTAssertEqual(back.returnID, leaving.id, "known by the id of the one that left")
        XCTAssertEqual(leaving.lifecycle, .released, "which is over")
        XCTAssertNotNil(back.returned, "and it is handed how that one was drawn")
        XCTAssertEqual(holder.presentedChildren.count, 2, "one view of it stands")
    }
}
