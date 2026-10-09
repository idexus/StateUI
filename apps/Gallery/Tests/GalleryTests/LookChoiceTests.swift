import StateUI
import XCTest

@testable import GalleryUI

/// A theme's look is kept as the user's choice: the gallery's own stands as that
/// choice, never as what the gallery's own was when the scene was kept.
@MainActor
final class LookChoiceTests: XCTestCase {
    /// A look nobody chose is kept as "own", and wears this version's own look.
    func testAnUntouchedLookIsKeptAsTheGallerysOwn() {
        let style = SessionStyle()

        XCTAssertEqual(style.lightChoice.persistentValue, .string("own"))
        XCTAssertEqual(style.darkChoice.persistentValue, .string("own"))
        XCTAssertEqual(style.look(dark: false), .light)
        XCTAssertEqual(style.look(dark: true), .dark)
    }

    /// A look the user changes is the user's composition, kept whole, and the
    /// gallery's own again once chosen.
    func testALookWrittenIsComposedUntilTheOwnIsChosenAgain() {
        let style = SessionStyle()
        style.darkLook.bars = .colour

        var composed = ThemeLook.dark
        composed.bars = .colour
        XCTAssertEqual(style.darkChoice, .composed(composed))
        XCTAssertEqual(LookChoice(rawValue: style.darkChoice.rawValue), .composed(composed), "kept and read back")
        XCTAssertEqual(style.lightChoice, .own, "the other theme untouched")

        style.darkChoice = .own
        XCTAssertEqual(style.look(dark: true), .dark)
    }

    /// A whole look an older gallery kept is no choice: the gallery starts in its own.
    func testALookAnOlderGalleryKeptIsNoChoice() {
        XCTAssertNil(LookChoice(rawValue: ThemeLook.dark.rawValue))
        XCTAssertNil(LookChoice(persisted: .string(ThemeLook.light.rawValue)))
    }
}
