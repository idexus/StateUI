// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidImageViewTests: XCTestCase {
    static var allTests: [(String, (AndroidImageViewTests) -> () throws -> Void)] {
        [
            ("testAPictureIsMeasuredAtItsOwnSizeInPoints", testAPictureIsMeasuredAtItsOwnSizeInPoints),
            ("testAPictureFillsOrFitsItsRoomAsItsAspectSays", testAPictureFillsOrFitsItsRoomAsItsAspectSays),
            ("testAPictureShownSmallIsReadAtFewerPixels", testAPictureShownSmallIsReadAtFewerPixels),
            ("testAPictureNoViewShowsIsLetGo", testAPictureNoViewShowsIsLetGo),
        ]
    }

    /// The colour `test_wide.svg` is drawn in.
    static let slate: UInt32 = 0xFF33_6699

    /// An SVG of 40 by 20 points, a PNG of 6 by 4 pixels kept at a pixel a point, and a name with no picture.
    func testAPictureIsMeasuredAtItsOwnSizeInPoints() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Image("test_wide.png").horizontalAlignment(.start)
                    Image("test_dot.png").horizontalAlignment(.start)
                    Image("nowhere.png").horizontalAlignment(.start)
                }
            }
            host.layOut()

            let images = host.views(AndroidImageView.self)
            XCTAssertEqual(images.count, 3)
            XCTAssertTrue(images[0].frame == (0, 0, 80, 40), "\(images[0].frame)")
            XCTAssertTrue(images[1].frame == (0, 40, 12, 8), "\(images[1].frame)")
            XCTAssertTrue(images[2].frame == (0, 48, 0, 0), "\(images[2].frame)")
            XCTAssertEqual(images[0].pixels(at: [(40, 20)]), [Self.slate])
        }
    }

    /// A wide picture in a square: filling it covers its corners, fitting it leaves them empty.
    func testAPictureFillsOrFitsItsRoomAsItsAspectSays() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Image("test_wide.png").aspect(.fill).width(20).height(20).horizontalAlignment(.start)
                    Image("test_wide.png").aspect(.fit).width(20).height(20).horizontalAlignment(.start)
                }
            }
            host.layOut()

            let images = host.views(AndroidImageView.self)
            XCTAssertEqual(images[0].pixels(at: [(1, 1), (20, 20)]), [Self.slate, Self.slate])
            XCTAssertEqual(images[1].pixels(at: [(1, 1), (20, 20)]), [0, Self.slate])
        }
    }

    /// `test_wide.svg` is 80 by 40 pixels at two pixels a point; shown at 20 by 10 points, half of it across
    /// and down is all the view needs, and it is still measured at its own size where nothing else is said.
    func testAPictureShownSmallIsReadAtFewerPixels() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Image("test_wide.png").aspect(.fill).width(20).height(10).horizontalAlignment(.start)
                    Image("test_wide.png").horizontalAlignment(.start)
                }
            }
            host.layOut()

            let images = host.views(AndroidImageView.self)
            let held = images[0].bitmapSize
            XCTAssertTrue(held.map { $0 == (40, 20) } == true, "\(String(describing: held))")
            XCTAssertEqual(images[0].pixels(at: [(20, 10)]), [Self.slate])
            XCTAssertTrue(images[1].frame == (0, 20, 80, 40), "\(images[1].frame)")
        }
    }

    /// A picture is kept while a view shows it: the last one leaving lets it go.
    func testAPictureNoViewShowsIsLetGo() throws {
        try onMainActor {
            let shown = State(wrappedValue: false)
            let before = AndroidPictures.keptCount
            let host = AndroidRenderer.running(reducesMotion: true) {
                VStack {
                    if shown.wrappedValue {
                        Image("test_wide.png").aspect(.fill).width(10).height(5)
                    }
                    Button("Flip").onClicked { shown.wrappedValue.toggle() }
                }
            }
            let flip = try XCTUnwrap(host.views(AndroidButtonView.self).first)

            flip.click()
            host.layOut()
            XCTAssertEqual(AndroidPictures.keptCount, before + 1, "the picture is read for the view showing it")

            flip.click()
            host.layOut()
            XCTAssertEqual(AndroidPictures.keptCount, before, "and let go when the view leaves")
        }
    }
}
