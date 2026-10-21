// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A color, from a hex number or read from text, and written as four bytes.
//
// The reader is StateUI's, so what a color may be is defined here rather
// than in the host: hex, in four lengths, checked below. A host that read
// colors for itself would have to reproduce that exactly or differ in
// silence.

import XCTest
@_spi(Host) @testable import StateUI

@MainActor
final class ColorTests: XCTestCase {
    // MARK: - A hex number

    /// The number's three bytes are red, green and blue, and the color is opaque.
    func testAHexNumberIsItsThreeChannels() {
        XCTAssertEqual(Color(hex: 0x512BD4).propValue, .color(red: 0x51, green: 0x2B, blue: 0xD4, alpha: 255))
        XCTAssertEqual(Color(hex: 0xFF0000), Color.red)
    }

    /// How opaque a hex color is becomes its alpha, held to 0-1 - as `opacity(_:)` holds it.
    func testOpacityIsTheAlphaOfAHexNumber() {
        XCTAssertEqual(Color(hex: 0xFF0000, opacity: 0.5).propValue, .color(red: 255, green: 0, blue: 0, alpha: 128))
        XCTAssertEqual(Color(hex: 0xFF0000, opacity: 0.5), Color.red.opacity(0.5))
        XCTAssertEqual(Color(hex: 0xFF0000, opacity: 2), Color.red)
        XCTAssertEqual(Color(hex: 0xFF0000, opacity: -1).propValue, .color(red: 255, green: 0, blue: 0, alpha: 0))
        XCTAssertEqual(Color(hex: 0xFF0000, opacity: .nan).propValue, .color(red: 255, green: 0, blue: 0, alpha: 0))
    }

    // MARK: - Reading text

    /// The four lengths hex is read in, and the shorthand doubling each digit.
    func testEveryLengthOfHexReadsTheSameColor() {
        XCTAssertEqual(Color(parsing: "#F00"), Color(parsing: "#FF0000"))
        XCTAssertEqual(Color(parsing: "#8F00"), Color(parsing: "#88FF0000"))
        XCTAssertEqual(Color(parsing: "#FF0000"), Color(parsing: "#FFFF0000"), "six digits are opaque")

        XCTAssertEqual(Color(parsing: "#80FF0000")?.propValue,
                       .color(red: 255, green: 0, blue: 0, alpha: 128))
    }

    /// Alpha comes FIRST in the four- and eight-digit forms, which is what
    /// ARGB means - and it is the channel a wrong reading gets away with
    /// longest, since most colors are opaque.
    func testAlphaIsTheFirstChannelWrittenAndTheLastOneSent() {
        XCTAssertEqual(Color(parsing: "#40204060")?.propValue,
                       .color(red: 0x20, green: 0x40, blue: 0x60, alpha: 0x40))
    }

    /// Case does not matter, and the `#` may be left off.
    func testHexIsReadInEitherCaseWithOrWithoutTheHash() {
        XCTAssertEqual(Color(parsing: "#ff0000"), Color.red)
        XCTAssertEqual(Color(parsing: "FF0000"), Color.red)
    }

    /// What is NOT hex is no color: the reader answers nil, and the data's own fallback stands.
    func testAnythingThatIsNotHexIsNotAColor() {
        XCTAssertNil(Color(parsing: "Red"), "a color NAME is Color.red, not a string")
        XCTAssertNil(Color(parsing: "#12345"))
        XCTAssertNil(Color(parsing: "#GGGGGG"))
        XCTAssertNil(Color(parsing: ""))
        XCTAssertNil(Color(parsing: "#123456789"))
        XCTAssertNil(Color(parsing: "rgb(255,0,0)"))
    }

    /// Equality is the COLOR, not its spelling - which is what stops two ways
    /// of writing one from reading as a change and being sent again.
    func testTwoSpellingsOfOneColorAreOneValue() {
        XCTAssertEqual(Color(hex: 0xFF0000), Color.red)
        XCTAssertEqual(Color(red: 255, green: 0, blue: 0), Color.red)
        XCTAssertEqual(Color(red: 255, green: 0, blue: 0, alpha: 255), Color.red)
        XCTAssertNotEqual(Color(red: 255, green: 0, blue: 0, alpha: 128), Color.red)
        XCTAssertEqual(Set([Color(hex: 0xFF0000), Color(red: 255, green: 0, blue: 0), Color.red]).count, 1,
                       "and hash alike")
    }

    /// A channel outside 0-255 is held to it rather than wrapping - which is
    /// what an Int argument makes possible in the first place.
    func testAChannelOutsideItsRangeIsHeldToIt() {
        XCTAssertEqual(Color(red: -20, green: 300, blue: 0), Color(hex: 0x00FF00))
    }

    // MARK: - What crosses

    /// A themed color crosses as ONE color: written, it is the pair, and
    /// the half in force is picked as the element wearing it is built - so
    /// a host never sees two. See Color.swift.
    func testAThemedColorCrossesAsTheHalfInForce() {
        let themed = Color(light: .white, dark: .black)

        XCTAssertEqual(
            themed.propValue,
            .themed(light: Color.white.propValue, dark: Color.black.propValue))
        XCTAssertEqual(themed.propValue.resolvingTheme(), Color.white.propValue)

        withTheme(.dark) {
            XCTAssertEqual(themed.propValue.resolvingTheme(), Color.black.propValue)
        }
    }

    // MARK: - A color inside a drawing

    /// A drawing is a list of RECORDS - one number for the canvas member, its
    /// arguments after it as the things they are - so a color in one crosses
    /// as the four bytes every other color crosses as, and the theme picks
    /// its half as the element holding the drawing is built.
    func testADrawingWritesEachColorAsItsFourChannels() {
        func drawn() -> PropValue? {
            Canvas { Draw.fillColor(Color(light: Color(hex: 0x6495ED), dark: .black)) }
                .node.props[.drawing]?.resolvingTheme()
        }

        // One record: the fillColor command's number, then the color itself.
        XCTAssertEqual(
            drawn(),
            .values([.values([
                .enumeration(0),
                .color(red: 0x64, green: 0x95, blue: 0xED, alpha: 0xFF),
            ])]))

        withTheme(.dark) {
            XCTAssertEqual(
                drawn(),
                .values([.values([
                    .enumeration(0),
                    .color(red: 0, green: 0, blue: 0, alpha: 0xFF),
                ])]))
        }
    }

    /// A color let through keeps its channels and scales its alpha, in both
    /// halves of a pair, held to the range a fraction has.
    func testAColorLetThroughScalesItsAlpha() {
        XCTAssertEqual(Color(hex: 0x512BD4).opacity(0.15), Color(hex: 0x512BD4, opacity: 0.15))
        XCTAssertEqual(Color(hex: 0xFFFFFF, opacity: 0.5).opacity(0.5), Color(hex: 0xFFFFFF, opacity: 0.25))
        XCTAssertEqual(
            Color(light: .white, dark: .black).opacity(0),
            Color(light: Color(hex: 0xFFFFFF, opacity: 0), dark: Color(hex: 0x000000, opacity: 0)))
        XCTAssertEqual(Color(hex: 0x512BD4).opacity(2), Color(hex: 0x512BD4))
    }

    /// A material crosses as itself and comes back so: a color as the color - so a color's channel writes a
    /// material - a gradient as its brush, a blur and glass with what stands in for them, a pair as its halves.
    func testAMaterialCrossesAsItselfWithWhatStandsInForIt() throws {
        XCTAssertEqual(Material.color(.tomato).propValue, Color.tomato.propValue, "a color's channel is a material's")
        XCTAssertEqual(Material.gradient(.solidColor(.tomato)), .color(.tomato), "a brush of one color is the color")

        let blur = Material.blur(.thin.tint(.indigo))
        XCTAssertEqual(Material(propValue: blur.propValue), blur)
        let parts = try XCTUnwrap(blur.propValue.values)
        XCTAssertEqual(parts.first, .enumeration(4))
        XCTAssertEqual(parts[3], Blur.Thickness.thin.standIn.propValue)
        XCTAssertTrue(parts[3].isThemed, "the stand-in follows the theme")

        let glass = Material.glass(.clear.tint(Color(hex: 0x512BD4)).isInteractive(true))
        XCTAssertEqual(Material(propValue: glass.propValue), glass)
        let glassParts = try XCTUnwrap(glass.propValue.values)
        XCTAssertEqual(glassParts[4], Blur.Thickness.ultraThin.propValue, "clear glass stands in as the thinnest blur")
        XCTAssertEqual(try XCTUnwrap(Material.glass(.regular).propValue.values)[4], Blur.Thickness.regular.propValue)

        let night = Material(light: nil, dark: .blur(.thick))
        XCTAssertEqual(night.propValue, .themed(light: .nothing, dark: Material.blur(.thick).propValue))
        XCTAssertEqual(Material(propValue: night.propValue), night)
        XCTAssertEqual(
            Material(light: .color(.white), dark: .color(.black)), .color(Color(light: .white, dark: .black)),
            "a pair of colors is the color pair")
        XCTAssertNil(Material(propValue: .nothing))
    }

    /// The accent crosses as the system's color, let through as it was asked, and the differ resolves it to the
    /// accent in force - the host never meets it.
    func testTheAccentIsTheOneInForce() {
        let info = StandardEnvironment.application.info
        let before = info.accentColor
        defer { HostBoundary.setAccentColor(before) }
        HostBoundary.setAccentColor(Color(hex: 0x0A84FF))

        XCTAssertEqual(Color.accent.propValue, .systemColor(0, alpha: 255))
        XCTAssertEqual(Color.accent.opacity(0.5).propValue, .systemColor(0, alpha: 128))
        XCTAssertEqual(Color(propValue: .systemColor(0, alpha: 128)), Color.accent.opacity(0.5))
        XCTAssertEqual(Color.accent.propValue.resolvingTheme(), Color(hex: 0x0A84FF).propValue)
        XCTAssertEqual(
            Color.accent.opacity(0.5).propValue.resolvingTheme(), Color(hex: 0x0A84FF, opacity: 0.5).propValue)
    }

    /// The accent as one half of a pair is the accent in force in that theme, not black; a pair handed as a half
    /// gives the half of that theme; and the pair reads back as itself.
    func testAPairKeepsTheAccentAndThePairsItIsMadeOf() {
        let info = StandardEnvironment.application.info
        let before = info.accentColor
        defer { HostBoundary.setAccentColor(before) }
        HostBoundary.setAccentColor(Color(hex: 0xFF0000))

        let accented = Color(light: .accent, dark: .white)
        XCTAssertEqual(accented.propValue.resolvingTheme(), Color(hex: 0xFF0000).propValue, "the accent in the light")
        withTheme(.dark) { XCTAssertEqual(accented.propValue.resolvingTheme(), Color.white.propValue) }
        XCTAssertEqual(Color(propValue: accented.propValue), accented, "and back")
        XCTAssertEqual(
            accented.opacity(0.5).propValue.resolvingTheme(), Color(hex: 0xFF0000, opacity: 0.5).propValue,
            "let through, still the accent")

        let surface = Color(light: .white, dark: .black)
        let nested = Color(light: .gray, dark: surface)
        withTheme(.dark) {
            XCTAssertEqual(nested.propValue.resolvingTheme(), Color.black.propValue, "a pair's dark half in the dark")
        }
    }
}
