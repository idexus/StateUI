// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Where things stand as every host places them: a picture in its room, a layout's children traveling to their
/// places, a frame report's numbers, and which changes measure or arrange again.
@MainActor
final class PlacesRulesTests: XCTestCase {
    /// A picture's name stands for its file, and a PNG's for the SVG of its name after it.
    func testAPicturesNameStandsForItsFiles() {
        XCTAssertEqual(PictureArithmetic.files(for: "logo.PNG"), ["logo.PNG", "logo.svg"])
        XCTAssertEqual(PictureArithmetic.files(for: "logo.jpg"), ["logo.jpg"])
        // A host that draws no SVG finds its drawing, made three times over as the application is built.
        let drawn = PictureArithmetic.drawnFiles(for: "logo.png")
        XCTAssertEqual(drawn.map(\.file), ["logo.png", "logo@3x.png"])
        XCTAssertEqual(drawn.map(\.scale), [1, 3])
    }

    /// A picture fits in or covers its room with its proportions kept, stands at its own size, or is stretched -
    /// each but the last in the room's middle.
    func testAPictureStandsInItsRoomByItsAspect() {
        let picture = LayoutSize(width: 40, height: 20)
        let room = LayoutSize(width: 100, height: 100)
        XCTAssertEqual(PictureArithmetic.place(picture, in: room, aspect: .fit), Rect(x: 0, y: 25, width: 100, height: 50))
        XCTAssertEqual(PictureArithmetic.place(picture, in: room, aspect: .fill), Rect(x: -50, y: 0, width: 200, height: 100))
        XCTAssertEqual(PictureArithmetic.place(picture, in: room, aspect: .center), Rect(x: 30, y: 40, width: 40, height: 20))
        XCTAssertEqual(PictureArithmetic.place(picture, in: room, aspect: .stretch), Rect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(
            PictureArithmetic.place(LayoutSize(width: 0, height: 0), in: room, aspect: .fit),
            Rect(x: 50, y: 50, width: 0, height: 0))
    }

    /// A vector picture is drawn at the size it shows at, in the display's pixels - the room's where it is
    /// stretched, sharp both ways - taken up to the next of four steps doubling its own size, then rounded up; at a
    /// step it is drawn at exactly that.
    func testAVectorPictureIsDrawnAtTheSizeItShowsAt() {
        let picture = LayoutSize(width: 20, height: 10)
        let room = LayoutSize(width: 30, height: 40)
        XCTAssertEqual(PictureArithmetic.vectorPixels(picture, in: room, aspect: .stretch, scale: 2),
                       LayoutSize(width: 68, height: 80), "each way its own step: 3.36 times across, 8 down")
        XCTAssertEqual(PictureArithmetic.vectorPixels(picture, in: room, aspect: .fit, scale: 1.5),
                       LayoutSize(width: 48, height: 24), "fitted, its proportions kept: 2.38 times either way")
        XCTAssertEqual(PictureArithmetic.vectorPixels(picture, in: LayoutSize(width: 40, height: 20), aspect: .fit, scale: 1),
                       LayoutSize(width: 40, height: 20), "twice its size is a step")
        XCTAssertEqual(PictureArithmetic.vectorPixels(picture, in: room, aspect: .center, scale: 1), picture,
                       "at its own size, its own")
    }

    /// A VECTOR PICTURE GROWING is drawn a few times on its way, never in every frame - a host standing a picture
    /// blank through each drawing, or drawing it on the UI thread, shows each one - and every drawing covers what it
    /// shows.
    func testAGrowingVectorPictureIsDrawnAFewTimes() {
        let picture = LayoutSize(width: 30, height: 40)
        var drawings = PictureDrawings()
        var made = 0
        for side in stride(from: 100.0, through: 400, by: 1) {
            let room = LayoutSize(width: side, height: side)
            if let pixels = drawings.asks(for: PictureArithmetic.vectorPixels(picture, in: room, aspect: .fit, scale: 1)) {
                XCTAssertTrue(drawings.landed(pixels))
                made += 1
            }
            let shown = PictureArithmetic.place(picture, in: room, aspect: .fit)
            XCTAssertGreaterThanOrEqual(drawings.shown?.height ?? 0, shown.height.rounded(.up), "covers at \(side)")
            XCTAssertLessThanOrEqual(drawings.shown?.height ?? 0, shown.height * 1.19 + 1, "no more than a step at \(side)")
        }
        XCTAssertLessThanOrEqual(made, 9, "drawn \(made) times over a growth of four times")
    }

    /// A drawing on its way is asked again only for more pixels than it holds; one that lands is shown only while
    /// it is the one on its way, and one not made leaves the next asking free to draw again.
    func testAPictureShowsWhatItHoldsUntilTheDrawingOnItsWayLands() {
        var drawings = PictureDrawings()
        let small = LayoutSize(width: 40, height: 40), large = LayoutSize(width: 80, height: 80)
        XCTAssertEqual(drawings.asks(for: small), small, "the first drawing")
        XCTAssertNil(drawings.asks(for: small), "on its way already")
        XCTAssertTrue(drawings.landed(small))
        XCTAssertNil(drawings.asks(for: LayoutSize(width: 30, height: 40)), "fewer pixels")

        XCTAssertEqual(drawings.asks(for: LayoutSize(width: 60, height: 60)), LayoutSize(width: 60, height: 60))
        XCTAssertEqual(drawings.asks(for: large), large, "grown past the one on its way")
        XCTAssertFalse(drawings.landed(LayoutSize(width: 60, height: 60)), "no longer the one on its way")
        XCTAssertEqual(drawings.shown, small, "what it held stays shown")
        XCTAssertTrue(drawings.landed(large))
        XCTAssertEqual(drawings.shown, large)

        XCTAssertNotNil(drawings.asks(for: LayoutSize(width: 90, height: 90)))
        drawings.lost(LayoutSize(width: 90, height: 90))
        XCTAssertEqual(drawings.asks(for: LayoutSize(width: 90, height: 90)), LayoutSize(width: 90, height: 90),
                       "asked again once the one on its way was not made")
    }

    /// A bar's or a tab's picture stands at the platform's icon height, as wide as its shape makes it, whatever size
    /// it is drawn at; one of no height stays as it is.
    func testABarsPictureStandsAtTheIconsHeight() {
        XCTAssertEqual(
            PictureArithmetic.glyph(LayoutSize(width: 96, height: 64), height: 24), LayoutSize(width: 36, height: 24))
        XCTAssertEqual(
            PictureArithmetic.glyph(LayoutSize(width: 10, height: 20), height: 24), LayoutSize(width: 12, height: 24))
        XCTAssertEqual(
            PictureArithmetic.glyph(LayoutSize(width: 5, height: 0), height: 24), LayoutSize(width: 5, height: 0))
    }

    /// A layout with no motion places its children at once; its first arrangement places them at once too; the
    /// arrangement after a patch sends them on their way.
    func testALayoutsChildrenTravelOnlyWhereAPatchSentThem() {
        let animator = Animator()
        let motion = LayoutMotion(animator: animator, now: { 0 }, reducesMotion: { false })
        motion.applicationMotion = .spring(response: .milliseconds(240))
        let places = TravelingPlaces()
        let child = Placed()
        var values = LayoutValues()
        values.width = 10

        places.begin(width: 100, height: 100)
        places.place(
            child, mount: 1, at: Rect(x: 0, y: 0, width: 10, height: 10), values: values, natural: { .zero },
            enter: nil)
        XCTAssertEqual(child.placedFrame, Rect(x: 0, y: 0, width: 10, height: 10), "no motion: at once")

        places.layoutMotion = motion
        places.begin(width: 100, height: 100)
        places.place(
            child, mount: 1, at: Rect(x: 0, y: 0, width: 10, height: 10), values: values, natural: { .zero },
            enter: nil)
        places.patchArrived()
        places.begin(width: 100, height: 100)
        places.place(
            child, mount: 1, at: Rect(x: 50, y: 0, width: 10, height: 10), values: values, natural: { .zero },
            enter: nil)
        XCTAssertTrue(animator.isMoving, "a patch's new place travels")
        XCTAssertEqual(child.placedFrame.x, 0, "and the child sets out from where it stood")
    }

    /// A frame report is the place in the parent, the corner in the window, and the corner from the content's.
    func testAFrameReportIsItsEightNumbers() {
        XCTAssertEqual(
            MountedElement.frameNumbers(
                place: Rect(x: 1, y: 2, width: 30, height: 40), corner: Point(x: 11, y: 52), content: Point(x: 0, y: 32)),
            [1, 2, 30, 40, 11, 52, 11, 20])
    }

    /// A view says where it stands once a layout placed it - StateUI's, or its toolkit's giving it a size - and
    /// never before: a view meets a display frame before the pass that places it.
    func testAViewSaysWhereItStandsOnlyOnceLaidOut() {
        XCTAssertFalse(MountedElement.isLaidOut(placed: false, width: 0, height: 0), "no layout placed it yet")
        XCTAssertTrue(MountedElement.isLaidOut(placed: true, width: 0, height: 0), "StateUI's layout placed it, empty")
        XCTAssertTrue(MountedElement.isLaidOut(placed: false, width: 40, height: 0), "the toolkit gave it a width")
        XCTAssertTrue(MountedElement.isLaidOut(placed: false, width: 0, height: 12), "or a height")
    }

    /// What only paints, places a cursor, reports a value or is read by assistive technology never asks for a new
    /// measure, on any host; what changes a size always does.
    func testOnlyWhatChangesASizeIsMeasuredAgain() {
        let drawn: Set<Prop> = [
            .opacity, .background, .textColor, .placeholderColor, .tint, .isEnabled,
            .isOn, .value, RangeElementContract.minimum.token, RangeElementContract.maximum.token,
            DatePickerContract.minimum.token, DatePickerContract.maximum.token, .progress, .cursorPosition, .selectionLength,
            ShapeContract.stroke.token, BorderElementContract.stroke.token, .fill, ShapeContract.lineWidth.token,
            BorderElementContract.lineWidth.token, .dash, .dashPhase, .lineCap, .lineJoin,
            .miterLimit, .shape, .cornerRadius, .geometryTransform, .barBackground, .barForegroundColor,
            .drawing, .scrollOffset, .clipsContent, .ignoresInput, .letsInputThrough,
        ]
        XCTAssertEqual(drawn.subtracting(MountedElement.unmeasuredProperties), [])
        XCTAssertEqual(
            MountedElement.unmeasuredProperties.intersection([
                .text, .fontSize, .fontFamily, .padding, VisualElementContract.width.token, .isVisible,
            ]),
            [])
    }

    /// A property is either read into a child's place or only drawn, never both.
    func testAPropertyArrangesOrIsOnlyDrawn() {
        XCTAssertEqual(MountedElement.arrangedProperties.intersection(MountedElement.unmeasuredProperties), [])
        XCTAssertTrue(MountedElement.unmeasuredProperties.isSuperset(of: MountedElement.transformProperties))
    }
}

/// A view that stands where it is placed.
@MainActor
private final class Placed: PlacedView {
    var placedFrame = Rect(x: 0, y: 0, width: 0, height: 0)
}
