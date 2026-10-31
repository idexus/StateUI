// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// The look a bar's own buttons wear: the application's style for every toolbar button, in the user's state.
@MainActor
final class BarOwnButtonsTests: XCTestCase {
    /// The style every toolbar button wears is the own buttons' too, its pointer-over state as the pointer comes,
    /// over the box the style every group wears gives them.
    func testTheOwnButtonsWearTheToolbarButtonsStyle() throws {
        stateUIUseApp(StyledBarApplication())
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()

        XCTAssertEqual(BarOwnButtons.look(pressed: false, pointerOver: false)[.background],
                       Material.color(Color(hex: 0x008000)).propValue)
        XCTAssertEqual(BarOwnButtons.look(pressed: false, pointerOver: true)[.background],
                       Material.color(Color(hex: 0x0000FF)).propValue)
        XCTAssertEqual(BarOwnButtons.look(pressed: false, pointerOver: false)[.stroke],
                       Brush.solidColor(Color(hex: 0x808080)).propValue, "the group's outline")
    }
}

private struct StyledBarApplication: Application {
    @Environment(\.application) private var application

    init() {
        application.styles = StyleSheet {
            Style<ToolbarGroup>().background(.white).stroke(.gray)
            Style<ToolbarButton>()
                .background(.green)
                .visualState(.pointerOver) { $0.background(.blue) }
        }
    }

    var body: some Scene {
        WindowGroup {
            Text("Notes").title("Notes").toolbar { ToolbarButton("Save") }
        }
    }
}
