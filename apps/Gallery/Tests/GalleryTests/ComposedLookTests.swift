import XCTest
@testable import GalleryUI

/// A theme's look is composed field by field, each field a state the scene keeps under a key of its own.
@MainActor
final class ComposedLookTests: XCTestCase {
    /// Each theme wears the gallery's own look until the user composes one.
    func testEachThemeWearsItsOwnLookAtFirst() {
        let style = SessionStyle()

        XCTAssertEqual(style.lightLook, .light)
        XCTAssertEqual(style.darkLook, .dark)
    }

    /// A field composed is worn by its theme alone; back to its own look, the theme's fields start from it again.
    func testAComposedFieldIsWornByItsThemeAlone() {
        let style = SessionStyle()

        style.darkBarsMaterial = .color
        style.darkComposed = true
        XCTAssertEqual(style.darkLook.bars.material, .color)
        XCTAssertEqual(style.lightLook, .light, "the other theme untouched")

        style.wearOwnLook(dark: true)
        XCTAssertEqual(style.darkLook, .dark)
        XCTAssertEqual(style.darkBarsMaterial, ThemeLook.dark.bars.material)
    }
}
