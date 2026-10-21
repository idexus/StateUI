// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// A key a view takes, heard with the keys held with it.
@MainActor
final class KeyPressTests: XCTestCase {
    /// What a view's handler heard.
    private final class Heard {
        var presses: [KeyPress] = []
    }

    /// A view hears the key it takes and whether Shift was held with it - Tab and Shift-Tab told apart - and a key
    /// it does not take reaches no handler.
    func testAViewHearsTheKeyAndWhatWasHeldWithIt() throws {
        let heard = Heard()
        let renders = Renders()
        let patch = renders.render(TextField("").onKeyPressed(.tab, .pageDown) { heard.presses.append($0) }.node)
        let pressed = try XCTUnwrap(patch.events?["keyPressed"])

        renders.fire(pressed, with: [Key.tab.propValue, KeyModifiers.shift.propValue])
        renders.fire(pressed, with: [Key.tab.propValue, KeyModifiers().propValue])
        renders.fire(pressed, with: [Key.pageDown.propValue, KeyModifiers().propValue])
        renders.fire(pressed, with: [Key.home.propValue, KeyModifiers().propValue])

        XCTAssertEqual(heard.presses, [KeyPress(.tab, modifiers: .shift), KeyPress(.tab), KeyPress(.pageDown)])
    }

    /// A space and a tab are one key each whichever way they are written: by name, or as the character.
    func testASpaceAndATabAreOneKeyEach() {
        XCTAssertEqual(Key(" "), .space)
        XCTAssertEqual(Key("\t"), .tab)
        XCTAssertNil(Key(" ").character)
        XCTAssertEqual(Key(" ").propValue, Key.space.propValue)
    }
}
