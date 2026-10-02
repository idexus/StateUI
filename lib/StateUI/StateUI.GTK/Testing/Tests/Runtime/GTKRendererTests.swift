// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import StateUIConformance
import XCTest

/// A page and its counter: a click raises the count, and the caption reads it.
struct CounterPage: ContentView {
    @State private var count = 0

    var content: some View {
        VStack {
            Text("count \(count)")
            Button("Add")
                .onClicked { count += 1 }
        }
    }
}

final class GTKRendererTests: XCTestCase {
    /// A page's controls are GTK's, shown in a window: the words it describes are the words GTK holds.
    func testThePageShowsItsControlsInAWindow() {
        onUIThread {
            let host = GTKRenderer.running { CounterPage() }

            XCTAssertEqual(host.views(GTKTextView.self).map(\.text), ["count 0"])
            XCTAssertEqual(host.views(GTKButtonView.self).map(\.text), ["Add"])
            XCTAssertNotNil(host.window?.content, "the window shows no page")
            XCTAssertEqual(gtk_widget_get_mapped(host.views(GTKButtonView.self)[0].widget), 1, "the button is not on screen")
        }
    }

    /// The proof of the host's spine: the click reaches the handler, the state it wrote renders, and the patch
    /// reaches GTK.
    func testAClickRendersWhatItsHandlerChanged() throws {
        try onUIThread {
            let host = GTKRenderer.running { CounterPage() }
            let button = try XCTUnwrap(host.views(GTKButtonView.self).first)

            button.click()
            button.click()

            XCTAssertEqual(host.views(GTKTextView.self).map(\.text), ["count 2"])
        }
    }

    func testAControlNoRegistrationAnswersShowsItsName() {
        onUIThread {
            let host = GTKRenderer.running { VStack { Map() } }

            XCTAssertEqual(host.views(GTKUnsupportedView.self).map(\.text), ["GTK: unsupported Map"])
        }
    }

    /// The window opens at the size its element says, and the user may make it no smaller than it says.
    func testTheWindowTakesTheSizeItsElementSays() throws {
        try onUIThread {
            let host = GTKRenderer.running { SizedPage() }
            let window = try XCTUnwrap(host.window).widget
            var size: (Int32, Int32) = (0, 0)
            gtk_window_get_default_size(window.of(GtkWindow.self), &size.0, &size.1)
            XCTAssertEqual(size.0, 700)
            XCTAssertEqual(size.1, 500)
            var least: (Int32, Int32) = (0, 0)
            gtk_widget_get_size_request(window, &least.0, &least.1)
            XCTAssertEqual(least.0, 400)
            XCTAssertEqual(least.1, 294, "GNOME's smallest where the element says none")
        }
    }

    /// The desktop's style, dark or light, is the application's theme.
    func testTheDesktopsStyleIsTheApplicationsTheme() {
        onUIThread {
            _ = GTKRenderer.running { Text("styled") }
            let dark = adw_style_manager_get_dark(adw_style_manager_get_default()) != 0

            XCTAssertEqual(StandardEnvironment.app.requestedTheme, dark ? .dark : .light)
        }
    }

    /// The window is titled as the window element says.
    func testTheWindowWearsItsTitle() throws {
        try onUIThread {
            let host = GTKRenderer.running { CounterPage() }
            host.window?.setTitle("Counter")

            let window = try XCTUnwrap(host.window)
            XCTAssertEqual(String(cString: gtk_window_get_title(window.widget.of(GtkWindow.self))), "Counter")
        }
    }
}

/// A page that sizes its window as it is made.
private struct SizedPage: ContentView {
    @Environment private var window: WindowSession

    var content: some View {
        let window = self.window
        return Text("sized").onCreated {
            window.width = 700
            window.height = 500
            window.minimumWidth = 400
        }
    }
}

extension GTKRendererTests {
    /// A window the tree closes tells nothing: GTK says it went, and that is the tree's own closing.
    func testAWindowTheTreeClosesTellsNothing() throws {
        try onUIThread {
            let host = GTKRenderer.running { PhasePage() }
            let window = try XCTUnwrap(host.window)
            host.settle { host.views(GTKTextView.self).first?.text.hasSuffix("activated") == true }
            let before = host.views(GTKTextView.self).map(\.text)

            window.close()
            for _ in 0..<10 { host.step() }

            XCTAssertEqual(host.views(GTKTextView.self).map(\.text), before, "no phase, no going")
        }
    }

    /// A window the user closes - its close button, Alt+F4 - hears it is going.
    func testAWindowTheUserClosesIsHeard() throws {
        try onUIThread {
            let gone = Received<String>()
            let host = GTKRenderer.running(application: { GoingApplication(gone: gone) })
            let window = try XCTUnwrap(host.window)

            gtk_window_close(window.widget.of(GtkWindow.self))
            host.settle { gone.values.contains("window") }

            XCTAssertEqual(gone.values, ["window"])
        }
    }

    /// A window of a kind of its own belongs to its scene's main window, as a tool window does on GNOME: above it, and
    /// gone with it; the main window belongs to none.
    func testAWindowOfItsOwnBelongsToTheMainWindow() throws {
        try onUIThread {
            let host = GTKRenderer.running(application: { ToolApplication() })
            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            host.settle { host.windows.count == 2 }

            XCTAssertEqual(host.windows.count, 2)
            let (main, tool) = (host.windows[0].window, host.windows[1].window)
            XCTAssertTrue(gtk_window_get_transient_for(tool.widget.of(GtkWindow.self)) == main.widget.of(GtkWindow.self))
            XCTAssertNil(gtk_window_get_transient_for(main.widget.of(GtkWindow.self)))
        }
    }
}

extension GTKRendererTests {
    /// A window's surface tells every change of its state, its tiling and its focus among them: the window says it
    /// is active or minimized again only where that changed, so a notice of something else unsays nothing.
    func testAWindowTellsItsStateOnlyWhereItChanged() throws {
        try onUIThread {
            let host = GTKRenderer.running { ScenePhaseLabel() }
            let phase = { host.views(GTKTextView.self).last?.text }
            let controller = try XCTUnwrap(host.windows.first)
            let element = try XCTUnwrap(controller.element)
            // The window's own activation comes as the desktop gives it: waited for, then told as it stands.
            host.settle { false }
            host.windowStateChanged(number: controller.window.number)

            host.runtime.windowStateChanged(element, minimized: false, activated: false)
            host.settle { phase() == "\(ScenePhase.inactive)" }
            host.windowStateChanged(number: controller.window.number)
            host.settle { false }

            XCTAssertEqual(phase(), "\(ScenePhase.inactive)")
        }
    }

    /// The page reads the machine the desktop describes: the locale GLib and the C library have, the power UPower
    /// has - none on a machine with no battery - and the network GIO has; none is left unknown.
    func testThePageReadsTheMachinesLocalePowerAndNetwork() throws {
        try onUIThread {
            let host = GTKRenderer.running { MachinePage() }
            let said = try XCTUnwrap(host.views(GTKTextView.self).first?.text).split(separator: " ").map(String.init)
            let language = g_get_language_names()?.pointee.map { String(cString: $0) } ?? ""

            XCTAssertEqual(said.count, 4, said.joined(separator: " "))
            guard said.count == 4 else { return }
            XCTAssertTrue(language.hasPrefix(said[0].replacingOccurrences(of: "-", with: "_")) || language == "C", said[0])
            XCTAssertFalse(said[1].isEmpty, "a time zone")
            XCTAssertNotEqual(said[2], "\(BatteryState.unknown)", "the power")
            XCTAssertNotEqual(said[3], "\(NetworkAccess.unknown)", "the network")
        }
    }
}

/// A page saying the locale's name and zone, the battery's state and the network's access.
private struct MachinePage: ContentView {
    @Environment private var locale: LocaleInfo
    @Environment private var battery: Battery
    @Environment private var connectivity: Connectivity

    var content: some View {
        Text("\(locale.name) \(locale.timeZone) \(battery.state) \(connectivity.networkAccess)")
    }
}

/// A page saying the application's phase and its window's.
private struct PhasePage: ContentView {
    @Environment private var application: ApplicationSession
    @Environment private var window: WindowSession

    var content: some View {
        Text("\(application.phase) \(window.phase)")
    }
}

/// An application whose window says when it is going.
private struct GoingApplication: Application {
    let gone: Received<String>

    var scene: any Scene { GoingScene(gone: gone) }
}

private struct GoingScene: Scene {
    let gone: Received<String>

    var windows: Windows {
        let gone = self.gone
        return Windows(main: { GoingWindow(gone: gone) })
    }
}

private struct GoingWindow: Window {
    let gone: Received<String>

    var page: any Page { GoingPage(gone: gone) }
}

/// A page hearing its window go.
private struct GoingPage: ContentView {
    let gone: Received<String>
    @Environment private var window: WindowSession

    var content: some View {
        let gone = self.gone
        let window = self.window
        return Text("going")
            .onChanged(window.phase) { if window.phase == .destroying { gone.values.append("window") } }
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

    var content: some View {
        let scene = self.scene
        return Button("Tool").onClicked { try await scene.openWindow(WindowType("renderer.tool")) }
    }
}

private struct ToolWindow: Window {
    var page: any Page { Text("A tool") }
}

/// A label reading its scene's phase, each phase it reads written down.
private struct ScenePhaseLabel: ContentView {
    @Environment private var scene: SceneSession

    var content: some View {
        Text("\(scene.phase)")
    }
}
