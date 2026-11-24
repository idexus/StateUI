// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import XCTest

final class AndroidImageViewTests: XCTestCase {
    static var allTests: [(String, (AndroidImageViewTests) -> () throws -> Void)] {
        [
            ("testAPictureIsMeasuredAtItsOwnSizeInPoints", testAPictureIsMeasuredAtItsOwnSizeInPoints),
            ("testAPictureFillsOrFitsItsRoomAsItsAspectSays", testAPictureFillsOrFitsItsRoomAsItsAspectSays),
            ("testAPictureShownSmallIsReadAtFewerPixels", testAPictureShownSmallIsReadAtFewerPixels),
            ("testAPictureShownSmallKeepsAsManyOfItsPixelsAsTheViewShows", testAPictureShownSmallKeepsAsManyOfItsPixelsAsTheViewShows),
            ("testAPictureNoViewShowsIsLetGo", testAPictureNoViewShowsIsLetGo),
            ("testAPictureNeededLargerIsReadBesideTheUIThread", testAPictureNeededLargerIsReadBesideTheUIThread),
            ("testAReadingLandingForAViewThatLeftIsLetGo", testAReadingLandingForAViewThatLeftIsLetGo),
            ("testEveryIconIsADrawableOfTheApplications", testEveryIconIsADrawableOfTheApplications),
            ("testAnIconIsDrawnInTheWordsColor", testAnIconIsDrawnInTheWordsColor),
            ("testAPictureThatArrivesIsPlacedAgainByTheLayoutMeasuringIt", testAPictureThatArrivesIsPlacedAgainByTheLayoutMeasuringIt),
        ]
    }

    /// A PICTURE THAT ARRIVES IS PLACED AGAIN BY THE LAYOUT MEASURING IT, with no patch behind it: told to its view
    /// as a late file is, it stands the words after it right of its width.
    /// Design: docs/design/host/layout.md#a-view-its-toolkit-sized-anew
    func testAPictureThatArrivesIsPlacedAgainByTheLayoutMeasuringIt() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                MotionLayout([0, 1], parameters: State(wrappedValue: 0.0).projectedValue) { index in
                    if index == 0 { Image("nowhere.png") } else { Text("after") }
                } placements: { context, _ in
                    var across = 0.0
                    return context.subviews.map { view in
                        let size = view.sizeThatFits()
                        defer { across += size.width }
                        return Placement(Rect(x: across, y: 0, width: size.width, height: size.height))
                    }
                }
            }
            defer { host.finish() }
            let picture = try XCTUnwrap(host.views(AndroidImageView.self).first)
            let layout = try XCTUnwrap(host.runtime.tree.root?.first(type: .motionLayout))
            // Where the layout's program puts the words: after the picture, as wide as it measured.
            let words = { layout.placement?.placements.last?.bounds.x ?? -1 }
            host.settle {
                host.layOut()
                host.frame()
                return words() == 0
            }
            XCTAssertEqual(words(), 0, "no picture yet: the words stand where the row begins")

            picture.apply(picture: HostPicture("test_wide.png", dark: false), aspect: .fit)
            host.settle {
                host.layOut()
                host.frame()
                return words() > 0
            }
            XCTAssertEqual(words(), 40, accuracy: 0.5, "placed by the size the picture arrived at")
        }
    }

    /// The color `test_wide.svg` is drawn in.
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
                    Image("test_wide.png").contentMode(.fill).width(20).height(20).horizontalAlignment(.start)
                    Image("test_wide.png").contentMode(.fit).width(20).height(20).horizontalAlignment(.start)
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
                    Image("test_wide.png").contentMode(.fill).width(20).height(10).horizontalAlignment(.start)
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

    /// Bytes are a picture at one pixel a point: 96 of them shown at 24 points, on a display of two pixels a point,
    /// need 48 of their own pixels across - read at one in two, never thinner, then scaled to the display's density.
    func testAPictureShownSmallKeepsAsManyOfItsPixelsAsTheViewShows() {
        onMainActor {
            let bytes = Java.frame { Java.bytesOf(Java.callStaticObject(TestJava.testPictures, TestJava.square, .int(96))) }
            let host = AndroidRenderer.running {
                Image(ImageSource(bytes: bytes)).width(24).height(24).horizontalAlignment(.start).verticalAlignment(.start)
            }
            host.layOut()

            let held = host.views(AndroidImageView.self).first?.bitmapSize
            XCTAssertTrue(held.map { $0 == (96, 96) } == true, "\(String(describing: held))")
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
                        Image("test_wide.png").contentMode(.fill).width(10).height(5)
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

    /// A VIEW PLACED LARGER KEEPS WHAT IT SHOWS while more of its picture's pixels are read beside the UI thread,
    /// and shows them once read: a card growing under the fingers never waits on a reading.
    /// Design: docs/design/platforms/android/drawing.md#pictures
    func testAPictureNeededLargerIsReadBesideTheUIThread() throws {
        try onMainActor {
            // 160 bytes' pixels, a picture no other view keeps, shown at 10 points on two pixels a point: one in 8.
            let bytes = Java.frame { Java.bytesOf(Java.callStaticObject(TestJava.testPictures, TestJava.square, .int(160))) }
            let side = State(wrappedValue: 10.0)
            let host = AndroidRenderer.running(reducesMotion: true) {
                VStack {
                    Image(ImageSource(bytes: bytes)).width(side.wrappedValue).height(side.wrappedValue)
                    Button("Grow").onClicked { side.wrappedValue = 20 }
                }
            }
            host.layOut()
            let image = try XCTUnwrap(host.views(AndroidImageView.self).first)
            XCTAssertTrue(image.bitmapSize.map { $0 == (40, 40) } == true, "\(String(describing: image.bitmapSize))")

            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()
            host.layOut()
            XCTAssertTrue(
                image.bitmapSize.map { $0 == (40, 40) } == true,
                "the UI thread read the picture again: \(String(describing: image.bitmapSize))")
            XCTAssertEqual(AndroidPictures.readingsOnTheirWay, 1)

            Self.waitForReadings()
            XCTAssertTrue(image.bitmapSize.map { $0 == (80, 80) } == true, "\(String(describing: image.bitmapSize))")
        }
    }

    /// A VIEW THAT LEAVES WHILE MORE OF ITS PIXELS ARE ON THEIR WAY TAKES NONE: the reading lands for no view and is
    /// let go.
    func testAReadingLandingForAViewThatLeftIsLetGo() {
        onMainActor {
            let bytes = Java.frame { Java.bytesOf(Java.callStaticObject(TestJava.testPictures, TestJava.square, .int(192))) }
            let side = State(wrappedValue: 10.0), shown = State(wrappedValue: true)
            let before = AndroidPictures.keptCount
            let host = AndroidRenderer.running(reducesMotion: true) {
                VStack {
                    if shown.wrappedValue {
                        Image(ImageSource(bytes: bytes)).width(side.wrappedValue).height(side.wrappedValue)
                    }
                    Button("Grow").onClicked { side.wrappedValue = 20 }
                    Button("Hide").onClicked { shown.wrappedValue = false }
                }
            }
            host.layOut()
            let buttons = host.views(AndroidButtonView.self)
            XCTAssertEqual(buttons.count, 2)

            buttons[0].click()
            host.layOut()
            XCTAssertEqual(AndroidPictures.readingsOnTheirWay, 1)
            buttons[1].click()
            host.layOut()
            Self.waitForReadings()
            XCTAssertEqual(AndroidPictures.readingsOnTheirWay, 0)
            XCTAssertEqual(AndroidPictures.keptCount, before)
        }
    }

    /// Turns the UI thread until the readings on their way have landed.
    @MainActor private static func waitForReadings() {
        for _ in 0..<100 {
            guard AndroidPictures.readingsOnTheirWay > 0 else { break }
            TestWindow.run(for: 20)
        }
    }

    /// Every icon is its Material Symbols drawable among the application's resources, read as a mask of Android's
    /// icon size.
    func testEveryIconIsADrawableOfTheApplications() {
        onMainActor {
            let side = Int32((24 * AndroidRenderer.density).rounded())
            for icon in Icon.allCases {
                let held = AndroidPictures.take(.icon(icon), sample: 1)
                let mask = held?.bitmap
                defer { if let held { AndroidPictures.letGo(held) } }
                guard let mask else {
                    XCTFail("no \(icon.androidDrawable) among the application's drawables")
                    continue
                }

                XCTAssertEqual(Java.callInt(mask.reference, JavaAPI.bitmapWidth), side, "\(icon)")
                XCTAssertEqual(Java.callInt(mask.reference, JavaAPI.bitmapHeight), side, "\(icon)")
                XCTAssertTrue(Java.callStaticBool(JavaAPI.views, TestJava.isMask, .object(mask.reference)), "\(icon)")
            }
        }
    }

    /// An icon standing alone is drawn in the words' color, as the label beside it is: its color, as opaque.
    func testAnIconIsDrawnInTheWordsColor() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                HStack {
                    Image(.platform(.add))
                    Text("Add")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            host.layOut()

            let image = try XCTUnwrap(host.views(AndroidImageView.self).first)
            let label = try XCTUnwrap(host.views(AndroidTextView.self).first)
            let ink = UInt32(bitPattern: Java.callStaticInt(TestJava.testPictures, TestJava.imageInk, .object(image.reference)))
            let color = UInt32(bitPattern: Java.callInt(label.reference, AndroidDriver.getCurrentTextColor))
            XCTAssertGreaterThan(ink >> 24, 0, "the icon is drawn")
            // A partly opaque pixel is kept premultiplied: its channels come back a few steps apart.
            for shift: UInt32 in [0, 8, 16] {
                let (drawn, given) = (Int(ink >> shift & 0xFF), Int(color >> shift & 0xFF))
                XCTAssertLessThanOrEqual(abs(drawn - given), 4, "\(String(ink, radix: 16)) for \(String(color, radix: 16))")
            }
            XCTAssertEqual(ink >> 24, color >> 24, "\(String(ink, radix: 16)) for \(String(color, radix: 16))")
        }
    }
}

extension TestJava {
    static let isMask = Java.staticMethod(JavaAPI.views, "isMask", "(Landroid/graphics/Bitmap;)Z")
    static let testPictures = Java.findClass("stateui/android/test/TestPictures")
    static let imageInk = Java.staticMethod(testPictures, "imageInk", "(Landroid/widget/ImageView;)I")
    static let iconInk = Java.staticMethod(testPictures, "iconInk", "(Landroid/widget/TextView;)I")
    static let aloneInk = Java.staticMethod(testPictures, "aloneInk", "(Landroid/widget/TextView;)I")
    static let square = Java.staticMethod(testPictures, "square", "(I)[B")
}
