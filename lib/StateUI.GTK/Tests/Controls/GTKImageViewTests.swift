// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
import XCTest

final class GTKImageViewTests: XCTestCase {
    /// The test's wide picture is an SVG, 40 by 20, of one colour.
    private static let wide: UInt32 = 0xFF33_6699

    /// An SVG is asked for by its PNG name, found, and drawn at the size it declares, in its colour.
    func testAnSVGAskedForByItsPNGNameIsDrawnAtItsOwnSize() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack { Image("test_wide.png") }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            let image = try XCTUnwrap(host.views(GTKImageView.self).first)
            XCTAssertTrue(image.found)
            host.settle { image.frame.width == 40 }

            XCTAssertTrue(image.frame == (0, 0, 40, 20), "\(image.frame)")
            XCTAssertEqual(image.pixels(at: [(20, 10)]), [Self.wide])
        }
    }

    /// A bitmap is its own size, however much room its layout offers.
    func testABitmapIsItsOwnSize() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack { Image("test_dot.png") }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            let image = try XCTUnwrap(host.views(GTKImageView.self).first)
            host.settle { image.frame.width == 6 }

            XCTAssertTrue(image.frame == (0, 0, 6, 4), "\(image.frame)")
            XCTAssertEqual(image.pixels(at: [(3, 2)]), [0xFFCC_3300])
        }
    }

    /// A picture read after its layouts were measured tells every layout above it, which grows around it.
    func testAPictureReadLateResizesTheLayoutsAboveIt() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack { HStack { Image("test_dot.png") } }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            let row = try XCTUnwrap(host.views(GTKStackView.self).last)
            host.settle { row.frame.width == 6 }

            XCTAssertTrue(row.frame == (0, 0, 6, 4), "\(row.frame)")
        }
    }

    /// Fitted, a wide picture is drawn whole across its room, with bands above and below.
    func testAFittedPictureIsDrawnWhole() throws {
        let colours = try drawn(.fit, width: 30, height: 30, at: [(15, 15), (15, 3), (15, 27)])
        XCTAssertEqual(colours, [Self.wide, 0, 0])
    }

    /// Filling, a wide picture covers its room, its sides cut off.
    func testAFillingPictureCoversItsRoom() throws {
        let colours = try drawn(.fill, width: 30, height: 30, at: [(1, 1), (15, 15), (28, 28)])
        XCTAssertEqual(colours, [Self.wide, Self.wide, Self.wide])
    }

    /// Stretched, a picture covers all of its room, whatever its own proportions.
    func testAStretchedPictureCoversItsRoom() throws {
        let colours = try drawn(.stretch, width: 30, height: 30, at: [(1, 1), (15, 28), (28, 1)])
        XCTAssertEqual(colours, [Self.wide, Self.wide, Self.wide])
    }

    /// Centred, a picture is drawn at its own size in the middle of its room.
    func testACentredPictureIsDrawnAtItsOwnSize() throws {
        let colours = try drawn(.center, width: 60, height: 60, at: [(30, 30), (12, 22), (5, 30), (30, 15)])
        XCTAssertEqual(colours, [Self.wide, Self.wide, 0, 0])
    }

    /// A picture the application does not have is found missing, and said so.
    func testAMissingPictureIsSaidMissing() throws {
        try onUIThread {
            let host = GTKRenderer.running { VStack { Image("nowhere.png") } }

            XCTAssertEqual(try XCTUnwrap(host.views(GTKImageView.self).first).found, false)
        }
    }

    /// The colours at `points` of the test's wide picture drawn as `aspect` says in a room `width` by `height`,
    /// read from the layout holding it, from the room's corner.
    private func drawn(
        _ aspect: Aspect, width: Double, height: Double, at points: [(Double, Double)]
    ) throws -> [UInt32] {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack { Image("test_wide.png").aspect(aspect).width(width).height(height) }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            let stack = try XCTUnwrap(host.views(GTKStackView.self).first)
            host.settle { stack.pixels(at: [(width / 2, height / 2)]) == [Self.wide] }
            return stack.pixels(at: points)
        }
    }
}
