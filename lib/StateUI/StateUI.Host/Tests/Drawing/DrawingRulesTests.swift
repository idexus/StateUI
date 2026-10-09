// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A fill, a box's corners and outline, and a shape's lines, as every host reads what the tree sends.
@MainActor
final class DrawingRulesTests: XCTestCase {
    private let red = Color(red: 255, green: 0, blue: 0).propValue
    private let blue = Color(red: 0, green: 0, blue: 255).propValue

    /// A bare colour is one colour; a gradient's stops stand between 0 and 1, and it runs top to bottom where it
    /// gives no geometry; its first colour is what a line of one colour draws.
    func testABrushIsReadAsTheTreeSendsIt() {
        XCTAssertEqual(HostBrush(red), .solid(red))
        XCTAssertEqual(HostBrush(nil), .none)
        let gradient = HostBrush(.values([.enumeration(2), .numbers([]), .number(-1), red, .number(2), blue]))
        XCTAssertEqual(gradient, .linear(
            from: Point(x: 0, y: 0), to: Point(x: 0, y: 1),
            stops: [HostBrush.Stop(offset: 0, color: red), HostBrush.Stop(offset: 1, color: blue)]))
        XCTAssertEqual(gradient.firstColor, red)
    }

    /// One colour of which nothing shows is clear - a clear bar; one that shows a breath of itself, a gradient
    /// and nothing at all are not.
    func testAColourNothingOfWhichShowsIsClear() {
        XCTAssertTrue(HostBrush(Color.transparent.propValue).isClear)
        XCTAssertFalse(HostBrush(Color(red: 0, green: 0, blue: 0, alpha: 5).propValue).isClear)
        XCTAssertFalse(HostBrush(red).isClear)
        XCTAssertFalse(HostBrush(nil).isClear, "nothing said is the platform's own, not clear")
        let fading = HostBrush(.values([.enumeration(2), .numbers([]), .number(0), Color.transparent.propValue,
                                        .number(1), blue]))
        XCTAssertFalse(fading.isClear)
    }

    /// A material is read as what paints it, the blur behind it, its glass and the colour standing in for the
    /// blur: a colour is its paint alone, a blur its tint over its thickness, glass the blur as clear as it is.
    @MainActor
    func testAMaterialIsReadWithWhatStandsInForIt() throws {
        XCTAssertEqual(HostMaterial(red).paint, red)
        XCTAssertNil(HostMaterial(red).blur)
        XCTAssertTrue(HostMaterial(nil).isEmpty)
        XCTAssertTrue(HostMaterial(.nothing).isEmpty)

        let thin = HostMaterial(Material.blur(.thin.tint(Color(red: 0, green: 0, blue: 255))).propValue.resolvingTheme())
        XCTAssertEqual(thin.blur, .thin)
        XCTAssertEqual(thin.paint, blue)
        XCTAssertNil(thin.glass)
        XCTAssertEqual(thin.standIn, Blur.Thickness.thin.standIn.propValue.resolvingTheme())

        let clear = HostMaterial(Material.glass(.clear.isInteractive(true)).propValue.resolvingTheme())
        XCTAssertEqual(clear.glass, HostMaterial.Glass(isClear: true, isInteractive: true))
        XCTAssertEqual(clear.blur, .ultraThin, "clear glass stands in as the thinnest blur")
        XCTAssertNil(clear.paint)
    }

    /// A host that blurs nothing paints the paint laid over the stand-in: a colour with an alpha tints it, an
    /// opaque one covers it, and no paint leaves the stand-in alone.
    @MainActor
    func testThePaintLiesOverTheStandIn() throws {
        let white = PropValue.color(red: 255, green: 255, blue: 255, alpha: 128)
        let tinted = { (tint: PropValue) in
            HostMaterial(.values([.enumeration(4), Blur.Thickness.thin.propValue, tint, white])).painted
        }
        XCTAssertEqual(tinted(.nothing), white)
        XCTAssertEqual(tinted(red), red, "an opaque tint covers the stand-in")
        XCTAssertEqual(
            tinted(.color(red: 255, green: 0, blue: 0, alpha: 128)), .color(red: 255, green: 85, blue: 85, alpha: 192),
            "half red over half white")
        XCTAssertEqual(HostMaterial(red).painted, red, "a colour paints itself")
    }

    /// A material read through its member comes encoded again, its pairs with it: the half of the theme in force
    /// is read - the stand-in's, the material's own.
    @MainActor
    func testAPairIsTheHalfOfTheThemeInForce() throws {
        guard case .themed(let light, let dark) = Blur.Thickness.thin.standIn.propValue else {
            return XCTFail("a blur's stand-in is a pair")
        }
        XCTAssertEqual(HostMaterial(Material.blur(.thin).propValue).standIn, HostThemes.current == .dark ? dark : light)
        let night = HostMaterial(Material(light: nil, dark: .blur(.thick)).propValue)
        XCTAssertEqual(night.isEmpty, HostThemes.current != .dark, "a nil half is the platform's own")
    }

    /// A gradient of one stop paints its one colour; of none, nothing - on every host, whatever its toolkit makes of
    /// a gradient that short.
    func testAGradientOfOneStopIsItsColour() {
        XCTAssertEqual(HostBrush(.values([.enumeration(2), .numbers([0, 0, 1, 1]), .number(0.5), red])), .solid(red))
        XCTAssertEqual(HostBrush(.values([.enumeration(3), .numbers([]), .number(1), blue])), .solid(blue))
        XCTAssertEqual(HostBrush(.values([.enumeration(2), .numbers([0, 0, 1, 1])])), .none)
    }

    /// A radial gradient runs out from its centre to its radius, in fractions of what it paints, and from the
    /// middle to the edge where it gives no geometry.
    func testARadialGradientIsReadFromItsCentreToItsRadius() {
        let stops = [HostBrush.Stop(offset: 0, color: red), HostBrush.Stop(offset: 1, color: blue)]
        let authored = Brush.radialGradient(
            [GradientStop(Color(red: 255, green: 0, blue: 0), 0), GradientStop(Color(red: 0, green: 0, blue: 255), 1)],
            center: Point(0.25, 0.75), radius: 0.4)

        let brush = HostBrush(authored.propValue)
        XCTAssertEqual(brush, .radial(center: Point(x: 0.25, y: 0.75), radius: 0.4, stops: stops))
        XCTAssertEqual(brush.firstColor, red)
        XCTAssertEqual(
            HostBrush(.values([.enumeration(3), .numbers([]), .number(0), red, .number(1), blue])),
            .radial(center: Point(x: 0.5, y: 0.5), radius: 0.5, stops: stops))
    }

    /// A radial gradient is a circle: its radius is its fraction of the larger side, whichever side that is.
    func testARadialGradientReachesAsFarAcrossAsDown() {
        XCTAssertEqual(HostBrush.reach(of: 0.5, width: 200, height: 100), 100)
        XCTAssertEqual(HostBrush.reach(of: 0.5, width: 100, height: 200), 100)
        XCTAssertEqual(HostBrush.reach(of: 0.25, width: 80, height: 80), 20)
    }

    /// A colour crosses to a relay as one number, alpha highest; what is no colour gives none.
    func testAColourIsOneARGBNumber() {
        XCTAssertEqual(Color(red: 0x12, green: 0x34, blue: 0x56, alpha: 0x78).propValue.argb, 0x7812_3456)
        XCTAssertNil(PropValue.number(1).argb)
    }

    /// Corners stand clockwise from the top left, never below nothing, and no corner rounds more than half its
    /// side.
    func testABoxsCornersStandClockwiseAndFitTheirRoom() {
        XCTAssertEqual(BoxArithmetic.clockwise(.corners(topLeft: 1, topRight: 2, bottomLeft: 3, bottomRight: -4)),
                       [1, 2, 0, 3])
        XCTAssertEqual(BoxArithmetic.clockwise(nil), [0, 0, 0, 0])
        XCTAssertTrue(BoxArithmetic.fitted(30, width: 100, height: 20) == (30, 10))
    }

    /// An outline is a rectangle where the tree asks none, a rounded one's radius never below nothing; it is drawn
    /// one wide where the tree gives a colour and no width, and not at all without a colour.
    func testAnOutlineIsReadAsTheTreeSendsIt() {
        XCTAssertEqual(BoxArithmetic.outline(nil), .rectangle)
        XCTAssertEqual(BoxArithmetic.outline(.values([.enumeration(1), .number(-3)])), .roundedRectangle(0))
        XCTAssertEqual(BoxArithmetic.outline(.values([.enumeration(2)])), .ellipse)
        XCTAssertEqual(BoxArithmetic.outlineWidth(stroke: red, width: nil), 1)
        XCTAssertEqual(BoxArithmetic.outlineWidth(stroke: nil, width: 4), 0)
        XCTAssertEqual(BoxArithmetic.outlineWidth(stroke: red, width: -2), 0)
    }

    /// Points are joined by lines, closed where the shape is, a point that is no number left out; dashes are
    /// stroke widths long.
    func testAShapesLinesAreItsPointsJoined() {
        let points = [Point(x: 0, y: 0), Point(x: .nan, y: 1), Point(x: 10, y: 5)]
        XCTAssertEqual(
            ShapeArithmetic.curves(through: points, closed: true),
            [.move(Point(x: 0, y: 0)), .line(Point(x: 10, y: 5)), .close])
        XCTAssertEqual(ShapeArithmetic.curves(through: [], closed: false), [])
        XCTAssertEqual(ShapeArithmetic.dashLengths([2, -1], lineWidth: 3), [6, 0])
        XCTAssertEqual(ShapeArithmetic.lineWidth(.infinity), 0)
    }

    /// Words on a dark band are light, on a light band dark; a value that is no colour decides nothing.
    func testWordsOnABandAreLightOnADarkOne() {
        XCTAssertEqual(BandWords.light(on: .color(red: 0, green: 0, blue: 128, alpha: 255)), true, "navy")
        XCTAssertEqual(BandWords.light(on: .color(red: 255, green: 0, blue: 0, alpha: 255)), true, "red")
        XCTAssertEqual(BandWords.light(on: .color(red: 255, green: 255, blue: 0, alpha: 255)), false, "yellow")
        XCTAssertEqual(BandWords.light(on: .color(red: 240, green: 240, blue: 240, alpha: 255)), false, "light grey")
        XCTAssertNil(BandWords.light(on: .number(1)))
    }

    /// Words on a band take the colour written for them, else white on a dark band and black on a light one; with
    /// no colour written and no band, the host's own.
    func testWordsOnABandTakeTheColourWrittenElseTheBands() {
        let navy = HostValue.color(red: 0, green: 0, blue: 128, alpha: 255)
        let yellow = HostValue.color(red: 255, green: 230, blue: 0, alpha: 255)
        let red = HostValue.color(red: 255, green: 0, blue: 0, alpha: 255)
        XCTAssertEqual(BandWords.color(on: navy, written: nil), .color(red: 255, green: 255, blue: 255, alpha: 255))
        XCTAssertEqual(BandWords.color(on: yellow, written: nil), .color(red: 0, green: 0, blue: 0, alpha: 255))
        XCTAssertEqual(BandWords.color(on: navy, written: red), red)
        XCTAssertEqual(BandWords.color(on: nil, written: red), red)
        XCTAssertNil(BandWords.color(on: nil, written: nil))
    }

    /// A view's own move, turn and scale drawn under a placing run's: the move turned and scaled by the run's, the
    /// turns added and the scales multiplied, about the centre; with no run, the view's own.
    func testAPlacedChildIsDrawnUnderItsRunsTransform() {
        let own = HostDrawingTransform(translationX: 10, rotation: 15, scaleX: 2, scaleY: 2, pivotX: 0, pivotY: 1)
        let run = HostDrawingTransform(translationX: 100, translationY: 50, rotation: 90, scaleX: 3, scaleY: 3)
        let drawn = own.under(run)

        XCTAssertEqual(drawn.translationX, 100, accuracy: 1e-9)
        XCTAssertEqual(drawn.translationY, 50 + 30, accuracy: 1e-9, "the move turned a quarter and made three times")
        XCTAssertEqual(drawn.rotation, 105, accuracy: 1e-9)
        XCTAssertEqual(drawn.scaleX, 6, accuracy: 1e-9)
        XCTAssertEqual(drawn.scaleY, 6, accuracy: 1e-9)
        XCTAssertEqual(drawn.pivotX, 0.5)
        XCTAssertEqual(drawn.pivotY, 0.5, "about the centre")
        XCTAssertEqual(own.under(nil), own)
    }
}
