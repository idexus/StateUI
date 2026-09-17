// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

/// Every phase the platform reports is a state the application sees: the host
/// renders after each one, so a push that reports a page's arrival and its
/// navigation in one native move still shows both.
final class AppKitPhaseTests: XCTestCase {
    @MainActor
    func testAPushedPageSeesItsArrivalAndItsNavigation() {
        let stack = PhaseStack()
        stateUIUseApp(PhaseApp(stack: stack))
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.startForTesting()

        stack.path = [1]
        renderer.pump()

        XCTAssertEqual(stack.seen, [.appearing, .navigatedTo])
    }
}

/// The stack the test pushes onto, and what its pushed page saw of its life.
private final class PhaseStack {
    @State var path: [Int] = []
    var seen: [PagePhase] = []
}

/// A page that writes down every phase it sees.
private struct PhasePage: ContentView {
    @Environment private var page: PageSession
    let stack: PhaseStack

    var content: any View {
        Label("pushed").onChanged(page.phase) { stack.seen.append(page.phase) }
    }
}

private struct PhaseWindow: Window {
    let stack: PhaseStack

    var page: any Page {
        NavigationStack(stack.$path) {
            Label("root")
        } destination: { _ in
            PhasePage(stack: stack)
        }
    }
}

private struct PhaseApp: Application {
    let stack: PhaseStack

    var scene: any Scene { PhaseWindow(stack: stack) }
}
#endif
