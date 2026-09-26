// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Where things stand as every host places them: a picture in its room, a layout's children travelling to their
/// places, a frame report's numbers, and which changes measure or arrange again.
@MainActor
final class PlacesRulesTests: XCTestCase {
    /// A picture's name stands for its file, and a PNG's for the SVG of its name after it.
    func testAPicturesNameStandsForItsFiles() {
        XCTAssertEqual(PictureArithmetic.files(for: "logo.PNG"), ["logo.PNG", "logo.svg"])
        XCTAssertEqual(PictureArithmetic.files(for: "logo.jpg"), ["logo.jpg"])
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

    /// A layout with no motion places its children at once; its first arrangement places them at once too; the
    /// arrangement after a patch sends them on their way.
    func testALayoutsChildrenTravelOnlyWhereAPatchSentThem() {
        let animator = Animator()
        let motion = LayoutMotion(animator: animator, now: { 0 }, reducesMotion: { false })
        motion.applicationMotion = .spring(response: 240)
        let places = TravellingPlaces()
        let child = Placed()
        var values = LayoutValues()
        values.width = 10

        places.begin(width: 100)
        places.place(child, mount: 1, at: Rect(x: 0, y: 0, width: 10, height: 10), values: values, fadeIn: nil)
        XCTAssertEqual(child.placedFrame, Rect(x: 0, y: 0, width: 10, height: 10), "no motion: at once")

        places.layoutMotion = motion
        places.begin(width: 100)
        places.place(child, mount: 1, at: Rect(x: 0, y: 0, width: 10, height: 10), values: values, fadeIn: nil)
        places.patchArrived()
        places.begin(width: 100)
        places.place(child, mount: 1, at: Rect(x: 50, y: 0, width: 10, height: 10), values: values, fadeIn: nil)
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
