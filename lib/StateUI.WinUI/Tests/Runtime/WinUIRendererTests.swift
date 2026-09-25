// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
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

        XCTAssertEqual(fields.count, 17, "the relay's callbacks changed; this test names how many there are")
        for field in fields {
            let value = Mirror(reflecting: field.value)
            XCTAssertFalse(value.displayStyle == .optional && value.children.isEmpty, "\(field.label ?? "?") is not set")
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
