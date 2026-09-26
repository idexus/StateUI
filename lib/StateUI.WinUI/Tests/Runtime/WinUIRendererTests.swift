// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
import XCTest

/// A page and its counter: a click raises the count, and the caption reads it.
struct CounterPage: ContentView {
    @State private var count = 0

    var content: any View {
        VStack {
            Label("count \(count)")
            Button("Add")
                .onClicked { count += 1 }
        }
    }
}

final class WinUIRendererTests: XCTestCase {
    /// A page's controls are WinUI's, shown in a window: the words it describes are the words WinUI holds.
    func testThePageShowsItsControlsInAWindow() {
        onUIThread {
            let host = WinUIRenderer.running { CounterPage() }

            XCTAssertEqual(host.views(WinUILabelView.self).map(\.text), ["count 0"])
            XCTAssertEqual(host.views(WinUIButtonView.self).map(\.text), ["Add"])
            XCTAssertNotNil(host.window?.content, "the window shows no page")
        }
    }

    /// The proof of the host's spine: the click reaches the handler, the state it wrote renders, and the patch
    /// reaches WinUI.
    func testAClickRendersWhatItsHandlerChanged() throws {
        try onUIThread {
            let host = WinUIRenderer.running { CounterPage() }
            let button = try XCTUnwrap(host.views(WinUIButtonView.self).first)

            button.invoke()
            button.invoke()

            XCTAssertEqual(host.views(WinUILabelView.self).map(\.text), ["count 2"])
        }
    }

    func testAControlNoRegistrationAnswersShowsItsName() {
        onUIThread {
            let host = WinUIRenderer.running { VStack { PositionIndicator() } }

            XCTAssertEqual(host.views(WinUIUnsupportedView.self).map(\.text), ["WinUI: unsupported PositionIndicator"])
        }
    }

    /// Every callback the relay declares is set: the relay calls them unchecked, and one left empty is a jump to nothing.
    func testEveryCallbackTheRelayMakesIsSet() {
        let fields = Mirror(reflecting: WinUICallbacks.table).children

        XCTAssertEqual(fields.count, 23, "the relay's callbacks changed; this test names how many there are")
        for field in fields {
            let value = Mirror(reflecting: field.value)
            XCTAssertFalse(value.displayStyle == .optional && value.children.isEmpty, "\(field.label ?? "?") is not set")
        }
    }

    /// A window the tree closes tells nothing: WinUI says it closed, and that is the tree's own closing.
    func testAWindowTheTreeClosesTellsNothing() throws {
        try onUIThread {
            let host = WinUIRenderer.running { PhasePage() }
            let window = try XCTUnwrap(host.window)
            let before = host.views(WinUILabelView.self).map(\.text)

            window.close()
            for _ in 0..<10 { host.step() }

            XCTAssertEqual(host.views(WinUILabelView.self).map(\.text), before, "no phase, no going")
        }
    }

    /// The state a window tells moves the application's phase, and its scene's and window's, settled in the turn
    /// after it: minimized, the window stops; shown again, it resumes on its way to being in use.
    func testTheWindowsStateMovesTheApplicationsPhaseAndItsOwn() throws {
        try onUIThread {
            let host = WinUIRenderer.running { PhasePage() }
            let window = try XCTUnwrap(host.window).number
            defer { WinUICallbacks.table.windowStateChanged(window, false, true) }

            WinUICallbacks.table.windowStateChanged(window, true, false)
            for _ in 0..<10 { host.step() }
            XCTAssertEqual(host.views(WinUILabelView.self).map(\.text), ["background stopped"])

            WinUICallbacks.table.windowStateChanged(window, false, true)
            for _ in 0..<10 { host.step() }
            XCTAssertEqual(host.views(WinUILabelView.self).map(\.text), ["active activated"])
        }
    }

    /// A window of a kind of its own belongs to its scene's main window, as a tool window does on Windows: above it,
    /// hidden with it, out of the switchers; the main window belongs to none.
    func testAWindowOfItsOwnBelongsToTheMainWindow() throws {
        try onUIThread {
            let host = WinUIRenderer.running(application: { ToolApplication() })
            let open = try XCTUnwrap(host.views(WinUIButtonView.self).first)

            stateui_winui_button_invoke(open.handle)
            for _ in 0..<30 where host.windows.count < 2 { host.step() }
            XCTAssertEqual(host.windows.count, 2)
            let (main, tool) = (host.windows[0].window, host.windows[1].window)
            XCTAssertTrue(stateui_winui_window_belongs_to(tool.handle, main.handle))
            XCTAssertFalse(stateui_winui_window_belongs_to(main.handle, tool.handle))
        }
    }

    /// The environment is Windows' own: the page reads a desktop running Windows, and the system's theme as Windows
    /// has it now.
    func testThePageReadsWindowsAndItsTheme() {
        onUIThread {
            let host = WinUIRenderer.running { EnvironmentPage() }
            var bytes = [CChar](repeating: 0, count: 8)
            _ = stateui_winui_facts(StateUIFactsTheme, nil, &bytes, 8)
            let dark = bytes[0] == 0x31

            XCTAssertEqual(host.views(WinUILabelView.self).map(\.text), ["Windows desktop", dark ? "dark" : "light"])
        }
    }
}

/// A page saying the application's phase and its window's.
private struct PhasePage: ContentView {
    @Environment private var application: ApplicationSession
    @Environment private var window: WindowSession

    var content: any View {
        Label("\(application.phase) \(window.phase)")
    }
}

/// An application whose main window opens a tool window of its scene.
private struct ToolApplication: Application {
    var scene: any Scene { ToolScene() }
}

private struct ToolScene: Scene {
    var windows: Windows {
        Windows({ WindowGroup(WindowType("renderer.tool")) { ToolWindow() } }, main: { ToolMainWindow() })
    }
}

private struct ToolMainWindow: Window {
    var page: any Page { ToolOpeningPage() }
}

private struct ToolOpeningPage: ContentView {
    @Environment private var scene: SceneSession

    var content: any View {
        let scene = self.scene
        return Button("Tool").onClicked { try await scene.openWindow(WindowType("renderer.tool")) }
    }
}

private struct ToolWindow: Window {
    var page: any Page { Label("A tool") }
}

/// A page saying what it runs on and the theme it runs in.
private struct EnvironmentPage: ContentView {
    @Environment private var device: DeviceInfo
    @Environment private var app: AppInfo

    var content: any View {
        VStack {
            Label("\(device.platform) \(device.formFactor)")
            Label("\(app.requestedTheme)")
        }
    }
}
