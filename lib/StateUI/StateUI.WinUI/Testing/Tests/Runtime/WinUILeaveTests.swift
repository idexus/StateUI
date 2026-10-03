// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
@_spi(Host) import StateUIConformance
import XCTest

/// A page whose note a click takes away.
struct NotePage: View {
    @State private var shown = true

    var body: some View {
        VStack {
            if shown {
                Text("note")
            }
            Button("Hide")
                .onClicked { shown = false }
        }
    }
}

final class WinUILeaveTests: XCTestCase {
    /// An element that leaves the tree lets go of its WinUI element: Swift holds one view fewer.
    func testAViewIsLetGoOfWhenItsElementLeaves() throws {
        try onUIThread {
            let host = WinUIRenderer.running { NotePage() }
            let before = WinUIView.liveCount
            XCTAssertEqual(host.views(WinUITextView.self).map(\.text), ["note"])

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            // A view's deinit is MainActor's, and runs in the turn after the one it left in.
            _ = host.runtime.core.runJobs()

            XCTAssertEqual(host.views(WinUITextView.self).count, 0)
            XCTAssertEqual(WinUIView.liveCount, before - 1, "the label's view outlived its element")
        }
    }

    /// Every element shown and taken away twice leaves the host holding as many views as the first time.
    func testEveryElementsViewIsLetGoOfEachTimeItLeaves() throws {
        try onUIThread {
            XCTAssertEqual(try Leaving.outlived(on: WinUIDriver()), [])
        }
    }

    /// A scroller that leaves lets go of its document and everything in it: Swift holds as many views as before the
    /// scroller came.
    func testAScrollerThatLeavesLetsGoOfItsDocument() throws {
        try onUIThread {
            let shown = State(wrappedValue: false)
            let host = WinUIRenderer.running {
                VStack {
                    if shown.wrappedValue {
                        ScrollView { VStack { Text("one"); Text("two") } }
                    }
                    Button("Toggle").onClicked { shown.wrappedValue.toggle() }
                }
            }
            let toggle = try XCTUnwrap(host.views(WinUIButtonView.self).first)
            let before = WinUIView.liveCount

            toggle.invoke()
            host.settle(until: { !host.views(WinUIScrollView.self).isEmpty })
            XCTAssertGreaterThan(WinUIView.liveCount, before)
            toggle.invoke()
            host.settle(until: { host.views(WinUIScrollView.self).isEmpty })
            _ = host.runtime.core.runJobs()

            XCTAssertEqual(WinUIView.liveCount, before, "the scroller's document outlived it")
        }
    }

    /// A list that leaves lets go of every cell WinUI asked it for and every item they held: Swift holds as many views
    /// as before the list came.
    func testAListThatLeavesLetsGoOfItsCells() throws {
        try onUIThread {
            let shown = State(wrappedValue: false)
            let host = WinUIRenderer.running {
                VStack {
                    if shown.wrappedValue {
                        ItemsView(0..<1_000) { Text("Item \($0)") }.height(300)
                    }
                    Button("Toggle").onClicked { shown.wrappedValue.toggle() }
                }
            }
            let toggle = try XCTUnwrap(host.views(WinUIButtonView.self).first)
            let before = WinUIView.liveCount

            toggle.invoke()
            host.settle(until: { host.views(WinUITextView.self).count > 5 })
            XCTAssertGreaterThan(host.views(WinUITextView.self).count, 5, "the list shows its first items")
            toggle.invoke()
            host.settle(until: { host.views(WinUIItemsView.self).isEmpty })
            _ = host.runtime.core.runJobs()

            XCTAssertEqual(WinUIView.liveCount, before, "the list's cells outlived it")
        }
    }

    /// A window the tree drops lets go of its chrome - its title bar, its menu bar, its row of tabs - and its page.
    func testAWindowTheTreeDropsLetsGoOfItsChrome() throws {
        try onUIThread {
            let host = WinUIRenderer.running(application: { LeavingToolApplication() })
            let buttons = host.views(WinUIButtonView.self)
            let (open, close) = try (XCTUnwrap(buttons.first { $0.text == "Open" }), XCTUnwrap(buttons.first { $0.text == "Close" }))
            let before = WinUIView.liveCount

            open.invoke()
            host.settle(until: { host.windows.count == 2 })
            XCTAssertGreaterThan(WinUIView.liveCount, before)
            close.invoke()
            host.settle(until: { host.windows.count == 1 })
            for _ in 0..<5 { host.step() }
            _ = host.runtime.core.runJobs()

            XCTAssertEqual(WinUIView.liveCount, before, "the window's chrome outlived it")
        }
    }
}

/// An application whose first window opens a tool window of its scene and closes it again.
private struct LeavingToolApplication: Application {
    var body: some Scene { LeavingToolScene() }
}

private struct LeavingToolScene: Scene {
    var body: some Scene {
        WindowGroup { LeavingOpeningPage() }
        Window(WindowType("leave.tool")) { Text("A tool") }
    }
}

private struct LeavingOpeningPage: View {
    @Environment private var application: ApplicationSession

    var body: some View {
        let application = self.application
        return VStack {
            Button("Open").onClicked { try await application.openWindow(WindowType("leave.tool")) }
            Button("Close").onClicked { try await application.closeWindow(WindowType("leave.tool")) }
        }
    }
}
