// The gallery's own styles, checked the way its catalog is.
//
// A style is written once and applies to everything, which is exactly what makes
// a mistake in one quiet: a target type spelled wrong, or two styles claiming
// the same key, changes nothing visible until somebody notices the control that
// never took its colour.

import XCTest
@testable import GalleryUI
@testable import StateUI

final class ResourceTests: XCTestCase {
    private var styles: [AnyStyle] {
        AppStyles.sheet(on: .unknown).written
    }

    /// Every type the gallery styles is one the renderer has a case for. The
    /// list is here rather than read from the library because it is the C# side
    /// that has to know these, and this is the Swift side saying which it uses.
    private static let renderable: Set<String> = [
        "Label", "Button", "ImageButton", "Entry", "Editor", "Picker",
        "DatePicker", "TimePicker", "SearchBar", "Switch", "CheckBox",
        "RadioButton", "Slider", "ActivityIndicator", "ProgressBar",
        "IndicatorView", "RefreshView", "Image", "BoxView", "Border",
        "Grid", "ScrollView", "VerticalStackLayout",
        "HorizontalStackLayout",
        // The gallery's own registered control - the renderer knows it
        // through StateUIControls, which is also where a Style targeting
        // it resolves its class.
        "Gallery.RatingBar",
    ]

    func testEveryStyleTargetsAControlThatExists() {
        XCTAssertFalse(styles.isEmpty)

        for style in styles {
            XCTAssertTrue(Self.renderable.contains(style.target.name),
                          "\(style.target.name) is not a control the renderer knows")
        }
    }

    /// A style with no setters is a style that does nothing, and the way to end
    /// up with one is a closure that forgot to return what it was given.
    func testEveryStyleActuallySetsSomething() {
        for style in styles {
            let key = style.key ?? style.target.name

            XCTAssertFalse(style.props.isEmpty, "\(key) sets nothing")

            for state in style.states {
                let name = state.props["name"]?.string ?? "?"

                // A state with no setters at all is the one the library adds so
                // a control has somewhere to return to. One that brought a
                // Setters node and left it empty is a mistake.
                guard let stateSetters = state.children.first(where: { $0.type == "Setters" })
                else { continue }

                XCTAssertFalse(stateSetters.props.isEmpty, "\(key) in \(name) sets nothing")
            }
        }
    }

    /// Two styles under one key means one of them is not there, and nothing
    /// says so.
    func testNothingIsFiledTwice() {
        var keys: Set<String> = []
        var implicitTargets: Set<String> = []

        for style in styles {
            if let key = style.key {
                XCTAssertTrue(keys.insert(key).inserted, "two styles answer to \"\(key)\"")
            } else {
                XCTAssertTrue(implicitTargets.insert(style.target.name).inserted,
                              "two implicit styles for \(style.target.name)")
            }
        }
    }

    /// The template's look is a light one and a dark one. A colour written for
    /// only one theme is the thing that reads wrong on the other, so most of
    /// them are written for both.
    ///
    /// Asked by building the sheet TWICE, once per theme, and counting the
    /// values that came out different - which is the only way to ask it since
    /// a colour picks its half as it is written. It also exercises the whole
    /// mechanism: if the resolution stopped reading the theme, the two sheets
    /// would come out identical and this would say so.
    func testTheStylesAreWrittenForBothThemes() {
        let held = StandardEnvironment.app.requestedTheme
        defer { StandardEnvironment.app.requestedTheme = held }

        StandardEnvironment.app.requestedTheme = .light
        let light = styles
        StandardEnvironment.app.requestedTheme = .dark
        let dark = styles

        XCTAssertEqual(light.count, dark.count)

        var themed = 0

        for (one, other) in zip(light, dark) {
            for (key, value) in one.props where other.props[key] != value {
                _ = key
                themed += 1
            }
        }

        XCTAssertGreaterThan(themed, 10, "hardly anything follows the theme")
    }

    /// The keyed styles the gallery asks for by name exist. A key nothing was
    /// filed under leaves the control with the default appearance and no word
    /// about it.
    func testTheKeysTheGalleryAsksForAreThere() {
        let keys = Set(styles.compactMap { $0.key })

        XCTAssertTrue(keys.contains("Headline"))
        XCTAssertTrue(keys.contains("SubHeadline"))

        // What the menu's rows are written against - see Gallery/Views/MenuRow.swift.
        XCTAssertTrue(keys.contains("MenuRow"))
        XCTAssertTrue(keys.contains("MenuRowText"))
    }

    /// A control starts in the FIRST state its group declares, so a style whose
    /// only state is Selected draws everything as selected. Measured, not
    /// assumed - it is what the flyout did before Normal was written down.
    ///
    /// Which state a control RESTS in is the target's, not always Normal: a
    /// RadioButton rests in Unchecked, because MAUI enters its own pair before
    /// the ordinary Normal and a Normal beside them would end every transition.
    func testAStyleWithStatesDeclaresItsTargetsRestingStateFirst() {
        for style in styles {
            guard let first = style.states.first?.props["name"]?.string else { continue }

            let resting = style.target == "RadioButton" ? "Unchecked" : "Normal"

            XCTAssertEqual(first, resting,
                           "\(style.key ?? style.target.name) starts in \(first)")
        }
    }

    /// The menu says which row you are on - and it is SWIFT that decides now.
    ///
    /// A Shell held the items, so MAUI selected one and a visual state said what
    /// that meant. The menu is a page and the application holds the section, so
    /// the chosen row writes its two values over the style it shares with every
    /// other row. Which means the style no longer proves anything by itself, and
    /// the thing worth pinning is that the two rows come out DIFFERENT.
    func testTheChosenMenuRowIsDrawnDifferentlyFromTheRest() {
        func drawn(chosen: Bool) -> Node {
            MenuRow("Layout", action: {}).icon("nav_layout.png").chosen(chosen).body
        }

        let on = drawn(chosen: true)
        let off = drawn(chosen: false)

        XCTAssertNotEqual(on.props["backgroundColor"], off.props["backgroundColor"],
                          "the row you are on looks like every other row")

        let onText = on.children.first { $0.props["text"] == .string("Layout") }
        let offText = off.children.first { $0.props["text"] == .string("Layout") }

        XCTAssertNotEqual(onText?.props["textColor"], offText?.props["textColor"])
        XCTAssertNotEqual(onText?.props["fontAttributes"], offText?.props["fontAttributes"])
    }
}
