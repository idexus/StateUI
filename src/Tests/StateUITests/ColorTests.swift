// A colour, read from hex and written as four bytes.
//
// The parser is this side's, so what a colour may be is defined here rather
// than in the host: hex, in MAUI's own four lengths, checked below. A host
// that read colours for itself would have to reproduce that exactly or differ
// in silence.

import StateUIWireProbe
import XCTest
@testable import StateUI

final class ColorTests: XCTestCase {
    // MARK: - Reading hex

    /// The four lengths MAUI reads, and the shorthand doubling each digit.
    func testEveryLengthOfHexReadsTheSameColour() {
        XCTAssertEqual(Color("#F00"), Color("#FF0000"))
        XCTAssertEqual(Color("#8F00"), Color("#88FF0000"))
        XCTAssertEqual(Color("#FF0000"), Color("#FFFF0000"), "six digits are opaque")

        XCTAssertEqual(Color("#80FF0000").propValue,
                       .color(red: 255, green: 0, blue: 0, alpha: 128))
    }

    /// Alpha comes FIRST in the four- and eight-digit forms, which is what
    /// ARGB means - and it is the channel a wrong reading gets away with
    /// longest, since most colours are opaque.
    func testAlphaIsTheFirstChannelWrittenAndTheLastOneSent() {
        XCTAssertEqual(Color("#40204060").propValue,
                       .color(red: 0x20, green: 0x40, blue: 0x60, alpha: 0x40))
    }

    /// Case does not matter, and the `#` may be left off - both are MAUI's own
    /// reading.
    func testHexIsReadInEitherCaseWithOrWithoutTheHash() {
        XCTAssertEqual(Color("#ff0000"), Color("#FF0000"))
        XCTAssertEqual(Color("FF0000"), Color("#FF0000"))
    }

    /// What is NOT hex answers nothing, which is what the initializer traps
    /// on - asked through the reader, since a trap cannot be caught.
    func testAnythingThatIsNotHexIsNotAColour() {
        XCTAssertNil(Color.channels(of: "Red"), "a colour NAME is Color.red, not a string")
        XCTAssertNil(Color.channels(of: "#12345"))
        XCTAssertNil(Color.channels(of: "#GGGGGG"))
        XCTAssertNil(Color.channels(of: ""))
        XCTAssertNil(Color.channels(of: "#123456789"))
        XCTAssertNil(Color.channels(of: "rgb(255,0,0)"))
    }

    /// Equality is the COLOUR, not its spelling - which is what stops two ways
    /// of writing one from reading as a change and being sent again.
    func testTwoSpellingsOfOneColourAreOneValue() {
        XCTAssertEqual(Color("#ff0000"), Color.red)
        XCTAssertEqual(Color.fromRgb(255, 0, 0), Color.red)
        XCTAssertEqual(Color.fromRgba(255, 0, 0, 255), Color.red)
        XCTAssertNotEqual(Color.fromRgba(255, 0, 0, 128), Color.red)
    }

    /// A channel outside 0-255 is held to it rather than wrapping - which is
    /// what an Int argument makes possible in the first place.
    func testAChannelOutsideItsRangeIsHeldToIt() {
        XCTAssertEqual(Color.fromRgb(-20, 300, 0), Color("#00FF00"))
    }

    // MARK: - What crosses

    /// Four bytes, in channel order, with the alpha last - written out one at
    /// a time so there is no word to agree an endianness for.
    func testAColourCrossesAsFourBytes() {
        var out: [UInt8] = []
        out.value(Color("#80204060").propValue)

        XCTAssertEqual(out, [8, 0x20, 0x40, 0x60, 0x80])
    }

    /// And a themed one crosses as ONE colour: the half in force, picked as
    /// the value is written. See Types/Color.swift.
    func testAThemedColourCrossesAsTheHalfInForce() {
        let themed = Color(light: .white, dark: .black)

        XCTAssertEqual(themed.propValue, Color.white.propValue)

        withTheme(.dark) {
            XCTAssertEqual(themed.propValue, Color.black.propValue)
        }
    }

    // MARK: - A colour inside a drawing

    /// A drawing is a list of RECORDS - one number for the canvas member, its
    /// arguments after it as the things they are - so a colour in one crosses
    /// as the four bytes every other colour crosses as, and the theme picks
    /// its half as the drawing is built.
    func testADrawingWritesEachColourAsItsFourChannels() {
        func drawn() -> PropValue? {
            GraphicsView { Draw.fillColor(Color(light: Color("#6495ED"), dark: .black)) }
                .body.props[.drawable]
        }

        // One record: the fillColor command's number, then the colour itself.
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
}
