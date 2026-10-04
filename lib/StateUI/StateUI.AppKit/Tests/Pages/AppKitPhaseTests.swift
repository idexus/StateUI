// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

/// Every phase the platform reports runs the handler the page's view gave it,
/// so a push that reports a page's arrival and its navigation in one native
/// move runs both.
final class AppKitPhaseTests: XCTestCase {
    @MainActor
    func testAPushedPageSeesItsArrivalAndItsNavigation() {
        let stack = PhaseStack()
        stateUIUseApp(PhaseApp(stack: stack))
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.startForTesting()

        stack.path = [1]
        renderer.runtime.pump.turn()

        XCTAssertEqual(stack.seen, ["appearing", "navigatedTo"])
    }
}

/// The stack the test pushes onto, and what its pushed page saw of its life.
private final class PhaseStack {
    @State var path: [Int] = []
    var seen: [String] = []
}

/// A page that writes down its arrival and its navigation.
private struct PhasePage: View {
    let stack: PhaseStack

    var body: some View {
        Text("pushed")
            .onAppearing { stack.seen.append("appearing") }
            .onNavigatedTo { stack.seen.append("navigatedTo") }
    }
}

private struct MainPage: View {
    let stack: PhaseStack

    var body: some View {
        NavigationStack(stack.$path) {
            Text("root")
        } destination: { _ in
            PhasePage(stack: stack)
        }
    }
}

private struct PhaseApp: Application {
    let stack: PhaseStack

    var body: some Scene { WindowGroup { MainPage(stack: stack) } }
}
#endif
