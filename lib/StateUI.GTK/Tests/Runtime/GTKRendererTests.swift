// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) @testable import StateUI
@testable import StateUIGTK
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

final class GTKRendererTests: XCTestCase {
    /// A page's controls are GTK's, shown in a window: the words it describes are the words GTK holds.
    func testThePageShowsItsControlsInAWindow() {
        onUIThread {
            let host = GTKRenderer.running { CounterPage() }

            XCTAssertEqual(host.views(GTKLabelView.self).map(\.text), ["count 0"])
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

            XCTAssertEqual(host.views(GTKLabelView.self).map(\.text), ["count 2"])
        }
    }

    func testAControlNoRegistrationAnswersShowsItsName() {
        onUIThread {
            let host = GTKRenderer.running { VStack { PositionIndicator() } }

            XCTAssertEqual(host.views(GTKUnsupportedView.self).map(\.text), ["GTK: unsupported PositionIndicator"])
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
            _ = GTKRenderer.running { Label("styled") }
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

    var content: any View {
        let window = self.window
        return Label("sized").onCreated {
            window.width = 700
            window.height = 500
            window.minimumWidth = 400
        }
    }
}
