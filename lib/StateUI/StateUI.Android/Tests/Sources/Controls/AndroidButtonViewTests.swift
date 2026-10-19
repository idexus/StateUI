// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import StateUIConformance
import CStateUIAndroid
import XCTest

final class AndroidButtonViewTests: XCTestCase {
    static var allTests: [(String, (AndroidButtonViewTests) -> () throws -> Void)] {
        [
            ("testAButtonIsAsBigAsItsWordsAndItsRoom", testAButtonIsAsBigAsItsWordsAndItsRoom),
            ("testALongPressOpensASplitButtonsMenuThoughItCanBeDragged", testALongPressOpensASplitButtonsMenuThoughItCanBeDragged),
            ("testAnIconAloneFitsTheRoomInsideThePadding", testAnIconAloneFitsTheRoomInsideThePadding),
            ("testAnIconBesideWordsStandsWhereItsPositionSays", testAnIconBesideWordsStandsWhereItsPositionSays),
            ("testAWideButtonsIconStandsBesideItsWords", testAWideButtonsIconStandsBesideItsWords),
            ("testALookIsOneShapeUnderThePlatformsRipple", testALookIsOneShapeUnderThePlatformsRipple),
            ("testALookThePageShowsThroughCastsNoShadow", testALookThePageShowsThroughCastsNoShadow),
            ("testADisabledLookDimsAsTheThemesControlsDo", testADisabledLookDimsAsTheThemesControlsDo),
            ("testAFingerDownAndUpArePressedAndReleased", testAFingerDownAndUpArePressedAndReleased),
            ("testAFamilyChangesTheTypeface", testAFamilyChangesTheTypeface),
            ("testAnIconIsDrawnInItsWordsColour", testAnIconIsDrawnInItsWordsColour),
            ("testAnIconAloneIsDrawnInTheWordsColour", testAnIconAloneIsDrawnInTheWordsColour),
            ("testAMenusArrowStandsAfterTheWords", testAMenusArrowStandsAfterTheWords),
            ("testASplitButtonsArrowIsNotItsClick", testASplitButtonsArrowIsNotItsClick),
            ("testWhatAButtonShowsStandsInTheMiddleBesideItsArrow", testWhatAButtonShowsStandsInTheMiddleBesideItsArrow),
            ("testADestructiveButtonsWordsStandInTheThemesErrorColour", testADestructiveButtonsWordsStandInTheThemesErrorColour),
        ]
    }

    /// A button is its words and its padding: the least size is the author's, never the platform theme's.
    func testAButtonIsAsBigAsItsWordsAndItsRoom() throws {
        try onMainActor {
            let host = AndroidRenderer.running(reducesMotion: true) {
                VStack {
                    Button("Go").horizontalAlignment(.center)
                    Button("Go").minimumWidth(120).horizontalAlignment(.center)
                }
            }
            host.layOut()
            let buttons = host.views(AndroidButtonView.self)
            let words = try XCTUnwrap(Self.words(of: buttons[0]))
            let room = Self.padding(of: buttons[0])

            XCTAssertEqual(buttons[0].frame.width, words.width + room.width, accuracy: 1)
            XCTAssertEqual(buttons[0].frame.height, words.height + room.height, accuracy: 1)
            XCTAssertEqual(buttons[1].frame.width, 240, "the author's least width, at two pixels a point")
        }
    }

    /// `test_wide.svg` is 80 by 40 pixels at two pixels a point: alone on a button of 40 by 40 points with 8 of
    /// padding, it fits the 48 pixels inside the padding, and stands in the middle.
    func testAnIconAloneFitsTheRoomInsideThePadding() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                Button(icon: "test_wide.png").width(40).height(40).padding(8).horizontalAlignment(.start)
            }
            host.layOut()
            let button = try XCTUnwrap(host.views(AndroidButtonView.self).first)

            let size = try XCTUnwrap(Self.layerSize(of: button))
            XCTAssertTrue(size == (48, 24), "\(size)")
            XCTAssertEqual(Self.besideWords(of: button), [false, false, false, false])
        }
    }

    func testAnIconBesideWordsStandsWhereItsPositionSays() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Button("Go").icon("test_wide.png")
                    Button("Go").icon("test_wide.png").iconPosition(.top)
                }
            }
            host.layOut()
            let buttons = host.views(AndroidButtonView.self)

            XCTAssertEqual(Self.besideWords(of: buttons[0]), [true, false, false, false])
            XCTAssertEqual(Self.besideWords(of: buttons[1]), [false, true, false, false])
            XCTAssertNil(Self.layerSize(of: buttons[0]), "no icon alone in the middle")
        }
    }

    /// A button wider than its words keeps its icon beside them, the two in the middle together - not the icon at
    /// the button's edge and the words alone in the middle; the room that takes is not the button's, which still
    /// measures as its twin of its own width does.
    func testAWideButtonsIconStandsBesideItsWords() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Button("Log out").icon("test_wide.png").width(300).horizontalAlignment(.start)
                    Button("Log out").icon("test_wide.png").horizontalAlignment(.start)
                }
            }
            host.layOut()
            let buttons = host.views(AndroidButtonView.self)
            let gap = try XCTUnwrap(Self.gapBesideWords(of: buttons[0]))

            XCTAssertLessThan(gap, 24, "the icon \(gap) pixels from its words")
            XCTAssertEqual(
                buttons[0].measure(width: ViewConstants.unspecified, height: ViewConstants.unspecified).width,
                buttons[1].measure(width: ViewConstants.unspecified, height: ViewConstants.unspecified).width,
                "the wide button measures as its twin")
        }
    }

    /// A fill, an outline and a shape are one shape under Android's own pressed ripple - an outline alone draws
    /// one too; nothing said keeps the theme's.
    func testALookIsOneShapeUnderThePlatformsRipple() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Button("Plain")
                    Button("Drawn").background(.firebrick).shape(.roundedRectangle(8))
                    Button("Outlined").stroke(.navy)
                }
            }
            let buttons = host.views(AndroidButtonView.self)

            XCTAssertEqual(Self.backgroundClass(of: buttons[1]), "android.graphics.drawable.RippleDrawable")
            XCTAssertEqual(Self.underTheRipple(of: buttons[1]), "stateui.android.StateUIShapeDrawable")
            XCTAssertEqual(Self.underTheRipple(of: buttons[2]), "stateui.android.StateUIShapeDrawable")
            XCTAssertNotEqual(Self.underTheRipple(of: buttons[0]), "stateui.android.StateUIShapeDrawable")
        }
    }

    /// A look the page shows through casts no shadow: the theme lifts a button, and the shadow of a shape seen
    /// through its fill reads as a grey fill. Only an opaque fill keeps the theme's shadow.
    func testALookThePageShowsThroughCastsNoShadow() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Button("Quiet").background(.transparent).stroke(.navy).lineWidth(1.5)
                        .shape(.roundedRectangle(10))
                    Button("Outlined").stroke(.navy)
                    Button("Drawn").background(.firebrick).shape(.roundedRectangle(8))
                }
            }
            host.layOut()

            XCTAssertEqual(host.views(AndroidButtonView.self).map(\.outlineAlpha), [0, 0, 1])
        }
    }

    /// A button drawn by its own look dims while it is disabled, as the theme's controls do.
    func testADisabledLookDimsAsTheThemesControlsDo() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Button("On").background(.firebrick).horizontalAlignment(.start)
                    Button("Off").background(.firebrick).isEnabled(false).horizontalAlignment(.start)
                }
            }
            host.layOut()
            let buttons = host.views(AndroidButtonView.self)
            let alpha = buttons.map { ($0.pixels(at: [(2, 2)]).first ?? 0) >> 24 }

            XCTAssertEqual(alpha[0], 255)
            XCTAssertLessThan(alpha[1], 200, "the disabled one drawn at the theme's disabled opacity")
            XCTAssertGreaterThan(alpha[1], 0)
        }
    }

    /// A finger going down is the press, and lifting it the release; the click that follows is Android's own
    /// post, and heard as any other click.
    func testAFingerDownAndUpArePressedAndReleased() throws {
        try onMainActor {
            let heard = Received<String>()
            let host = AndroidRenderer.running {
                Button("Hold")
                    .onPressed { heard.values.append("pressed") }
                    .onReleased { heard.values.append("released") }
            }
            host.layOut()
            let button = try XCTUnwrap(host.views(AndroidButtonView.self).first)

            button.touch(0, x: 4, y: 4)
            XCTAssertEqual(heard.values, ["pressed"])
            button.touch(1, x: 4, y: 4)
            XCTAssertEqual(heard.values, ["pressed", "released"])
        }
    }

    func testAFamilyChangesTheTypeface() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Button("Plain")
                    Button("Fixed").fontFamily("monospace")
                }
            }
            let buttons = host.views(AndroidButtonView.self)
            let faces = buttons.map { button in
                Java.frame { Java.callObject(button.reference, TestJava.getTypeface).map(JavaObject.init) }
            }

            XCTAssertFalse(Java.jni.IsSameObject(Java.env, faces[0]?.reference, faces[1]?.reference) != 0)
        }
    }

    /// A button whose click opens its menu shows an arrow after its words and keeps room for it, unless it shows
    /// none; a split button's arrow stands at its edge, set off by a line.
    func testAMenusArrowStandsAfterTheWords() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Button("Share").menu { MenuItem("Mail") }
                    Button("Share").menu { MenuItem("Mail") }.showsMenuArrow(false)
                    Button("Save").onClicked {}.menu { MenuItem("Save as") }
                    Button("Save").onClicked {}.menu(.held) { MenuItem("Save as") }
                }
            }
            host.layOut()
            let buttons = host.views(AndroidButtonView.self)

            XCTAssertEqual(buttons.map(Self.layers(of:)), [[2], [], [3, 4], []], "a mark, none, an arrow and its line")
            XCTAssertGreaterThan(Self.padding(of: buttons[0]).width, Self.padding(of: buttons[1]).width, "room for it")
            XCTAssertGreaterThan(Self.padding(of: buttons[2]).width, Self.padding(of: buttons[0]).width)
        }
    }

    /// A long press on a split button opens its menu - the road TalkBack offers - whether or not the button can be
    /// dragged: one owner decides what a long press does.
    func testALongPressOpensASplitButtonsMenuThoughItCanBeDragged() throws {
        try onMainActor {
            let drags = State(wrappedValue: true)
            let heard = Received<String>()
            let host = AndroidRenderer.running {
                Button("Save").onClicked {}.menu { MenuItem("Save as") }
                    .draggable(text: "Save", canDrag: drags.wrappedValue) { heard.values.append("drag") }
            }
            host.layOut()
            let save = try XCTUnwrap(host.views(AndroidButtonView.self).first)

            XCTAssertTrue(Java.callBool(save.reference, Self.performLongClick), "held, it opens its menu")
            drags.wrappedValue = false
            host.runtime.pump.turn()
            XCTAssertTrue(Java.callBool(save.reference, Self.performLongClick), "and so where it cannot be dragged")
            XCTAssertEqual(heard.values, [], "no drag")
        }
    }

    @MainActor private static let performLongClick = Java.method(JavaAPI.view, "performLongClick", "()Z")

    /// A finger on a split button's arrow opens its menu rather than clicking it; anywhere else it clicks it.
    func testASplitButtonsArrowIsNotItsClick() throws {
        try onMainActor {
            let heard = Received<String>()
            let host = AndroidRenderer.running {
                Button("Save").onClicked { heard.values.append("save") }.menu { MenuItem("Save as") }
            }
            host.layOut()
            let save = try XCTUnwrap(host.views(AndroidButtonView.self).first)
            let (_, _, width, height) = save.frame

            // Down where the finger clicks, lifted off the button, so the click is the test's alone.
            @MainActor func click(at x: Float) {
                save.touch(0, x: x, y: Float(height) / 2)
                save.touch(1, x: -100, y: -100)
                save.click()
            }
            click(at: Float(width) - 8)
            XCTAssertEqual(heard.values, [], "the arrow")
            click(at: 8)
            XCTAssertEqual(heard.values, ["save"], "the button")
        }
    }

    /// What a button holding a menu shows stands in the middle beside its arrow: words with the arrow after them one
    /// group, as far from either edge; a picture alone in the middle of the room before the arrow.
    func testWhatAButtonShowsStandsInTheMiddleBesideItsArrow() throws {
        try onMainActor {
            let host = AndroidRenderer.running(reducesMotion: true) {
                HStack {
                    Button("Share").menu { MenuItem("Mail") }.padding(horizontal: 16, vertical: 8)
                    Button(icon: .icon(.more)).menu { MenuItem("Mail") }.padding(horizontal: 16, vertical: 8)
                }
                .horizontalAlignment(.start)
            }
            host.layOut()
            let buttons = host.views(AndroidButtonView.self)
            let (share, more) = (buttons[0], buttons[1])

            // Material's arrow fills the middle half of its square across.
            let width = Float(share.frame.width)
            let wordsLeft = try XCTUnwrap(Self.wordsLeft(of: share))
            let (markWidth, markRight) = try XCTUnwrap(Self.layer(0, of: share))
            let arrowRight = width - Float(markRight) - Float(markWidth) / 4
            XCTAssertEqual(wordsLeft, width - arrowRight, accuracy: 2, "words at \(wordsLeft), arrow to \(arrowRight)")

            let (_, pictureRight) = try XCTUnwrap(Self.layer(0, of: more))
            let left = Java.callInt(more.reference, JavaAPI.getPaddingLeft)
            let right = Java.callInt(more.reference, JavaAPI.getPaddingRight)
            let room = (Float(left) + Float(more.frame.width) - Float(right)) / 2
            XCTAssertEqual((Float(more.frame.width) - Float(pictureRight)) / 2, room, accuracy: 1, "the picture's middle")
        }
    }

    /// Where the button's line of words begins, in pixels of its own.
    @MainActor
    private static func wordsLeft(of button: AndroidButtonView) -> Float? {
        guard let layout = Java.callObject(button.reference, TestJava.getLayout) else { return nil }
        defer { Java.release(local: layout) }
        return Float(Java.callInt(button.reference, JavaAPI.getCompoundPaddingLeft))
            + Java.callFloat(layout, TestJava.getLineLeft, .int(0))
    }

    /// The width of the foreground's layer `index` and how far its room stands in from the right, in pixels.
    @MainActor
    private static func layer(_ index: Int32, of button: AndroidButtonView) -> (Int32, Int32)? {
        Java.frame {
            guard let layer = Java.callObject(button.reference, TestJava.getForeground) else { return nil }
            return (Java.callInt(layer, TestJava.getLayerWidth, .int(index)),
                    Java.callInt(layer, TestJava.getLayerInsetRight, .int(index)))
        }
    }

    /// The ids of the layers the button's foreground draws, in order.
    @MainActor
    private static func layers(of button: AndroidButtonView) -> [Int32] {
        Java.frame {
            guard let layer = Java.callObject(button.reference, TestJava.getForeground),
                  Java.jni.IsInstanceOf(Java.env, layer, TestJava.layerDrawable) != 0
            else { return [] }
            return (0..<Java.callInt(layer, TestJava.getNumberOfLayers)).map { Java.callInt(layer, TestJava.getId, .int($0)) }
        }
    }

    /// The size of the icon standing alone in the middle, in pixels; nil where none does.
    @MainActor
    private static func layerSize(of button: AndroidButtonView) -> (Int32, Int32)? {
        Java.frame {
            guard let layer = Java.callObject(button.reference, TestJava.getForeground) else { return nil }
            return (Java.callInt(layer, TestJava.getLayerWidth, .int(0)), Java.callInt(layer, TestJava.getLayerHeight, .int(0)))
        }
    }

    /// Whether a picture stands before the words, above them, after them and below them.
    @MainActor
    private static func besideWords(of button: AndroidButtonView) -> [Bool] {
        Java.frame {
            guard let drawables = Java.callObject(button.reference, TestJava.getCompoundDrawablesRelative) else { return [] }
            return (0..<4).map { index in
                let drawable = Java.jni.GetObjectArrayElement(Java.env, drawables, jsize(index))
                defer { Java.release(local: drawable) }
                return drawable != nil
            }
        }
    }

    /// The Java class of what the button's background draws first: under a ripple, its content.
    @MainActor
    private static func underTheRipple(of button: AndroidButtonView) -> String {
        Java.frame {
            guard let background = Java.callObject(button.reference, JavaAPI.getBackground),
                  let content = Java.callObject(background, TestJava.getLayer, .int(0)),
                  let type = Java.callObject(content, TestJava.getClass)
            else { return "" }
            return Java.text(Java.callObject(type, TestJava.getName))
        }
    }

    /// The Java class of the button's background.
    @MainActor
    private static func backgroundClass(of button: AndroidButtonView) -> String {
        Java.frame {
            guard let background = Java.callObject(button.reference, JavaAPI.getBackground),
                  let type = Java.callObject(background, TestJava.getClass)
            else { return "" }
            return Java.text(Java.callObject(type, TestJava.getName))
        }
    }

    /// The pixels the button's one line of words takes.
    @MainActor
    private static func words(of button: AndroidButtonView) -> (width: Int32, height: Int32)? {
        guard let layout = Java.callObject(button.reference, TestJava.getLayout) else { return nil }
        defer { Java.release(local: layout) }
        let width = Java.callFloat(layout, TestJava.getLineWidth, .int(0))
        return (Int32(width.rounded(.up)), Java.callInt(layout, TestJava.getLayoutHeight))
    }

    /// The pixels between the picture before the words and the words: the drawable's padding, and where the line
    /// of words starts in the room beside the picture.
    @MainActor
    private static func gapBesideWords(of button: AndroidButtonView) -> Float? {
        guard let layout = Java.callObject(button.reference, TestJava.getLayout) else { return nil }
        defer { Java.release(local: layout) }
        return Java.callFloat(layout, TestJava.getLineLeft, .int(0))
            + Float(Java.callInt(button.reference, TestJava.getCompoundDrawablePadding))
    }

    /// The pixels of padding around the button's words, across and down.
    @MainActor
    private static func padding(of button: AndroidButtonView) -> (width: Int32, height: Int32) {
        let reference = button.reference
        return (
            Java.callInt(reference, JavaAPI.getPaddingLeft) + Java.callInt(reference, JavaAPI.getPaddingRight),
            Java.callInt(reference, JavaAPI.getPaddingTop) + Java.callInt(reference, JavaAPI.getPaddingBottom)
        )
    }

    /// An icon beside a button's words is drawn in their colour.
    func testAnIconIsDrawnInItsWordsColour() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                Button("Add").icon(.icon(.add)).textColor(Color("#FF0000"))
            }
            host.layOut()

            let button = try XCTUnwrap(host.views(AndroidButtonView.self).first)
            let ink = UInt32(bitPattern: Java.callStaticInt(
                TestJava.testPictures, TestJava.iconInk, .object(button.reference)))
            XCTAssertGreaterThan(ink >> 24, 0, "the icon is drawn")
            XCTAssertEqual(ink & 0xFF_FFFF, 0xFF_0000, String(ink, radix: 16))
            XCTAssertEqual(ink >> 24, 0xFF, "as opaque as its words: \(String(ink, radix: 16))")
        }
    }

    /// An icon standing alone in a button with no words gives the button its size - the icon's own inside the
    /// padding - and is drawn in the colour its words would take.
    func testAnIconAloneIsDrawnInTheWordsColour() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                Button(icon: .icon(.settings)).textColor(Color("#FF0000"))
                    .horizontalAlignment(.start).verticalAlignment(.start)
            }
            host.layOut()

            let button = try XCTUnwrap(host.views(AndroidButtonView.self).first)
            XCTAssertGreaterThanOrEqual(button.frame.width, 24, "\(button.frame)")
            XCTAssertGreaterThanOrEqual(button.frame.height, 24, "\(button.frame)")
            let ink = UInt32(bitPattern: Java.callStaticInt(
                TestJava.testPictures, TestJava.aloneInk, .object(button.reference)))
            let padding = [JavaAPI.getPaddingLeft, JavaAPI.getPaddingTop, JavaAPI.getPaddingRight, JavaAPI.getPaddingBottom]
                .map { Java.callInt(button.reference, $0) }
            XCTAssertGreaterThan(ink >> 24, 0, "the icon is drawn: \(button.frame) padding \(padding)")
            XCTAssertEqual(ink & 0xFF_FFFF, 0xFF_0000, String(ink, radix: 16))
            XCTAssertEqual(ink >> 24, 0xFF, "as opaque as its words: \(String(ink, radix: 16))")
        }
    }

    /// A destructive action's words stand in the theme's colour for an error where the tree colours them not; a
    /// colour the tree states wins.
    func testADestructiveButtonsWordsStandInTheThemesErrorColour() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Button("Delete").role(.destructive)
                    Button("Erase").role(.destructive).textColor(Color("#0000FF"))
                    Button("Plain")
                }
            }
            host.layOut()

            let buttons = host.views(AndroidButtonView.self)
            XCTAssertEqual(buttons.count, 3)
            let error = try XCTUnwrap(Java.frame {
                Java.callStaticObject(JavaAPI.views, JavaAPI.errorWords, .object(AndroidRenderer.context))
                    .map { Java.callInt($0, TestJava.getDefaultColor) }
            })
            let words = buttons.map { button in
                Java.frame {
                    Java.callObject(button.reference, JavaAPI.getTextColors).map { Java.callInt($0, TestJava.getDefaultColor) }
                }
            }
            XCTAssertEqual(words[0], error, "the theme's error colour")
            XCTAssertEqual(words[1].map { UInt32(bitPattern: $0) & 0xFF_FFFF }, 0x00_00FF, "the tree's colour wins")
            XCTAssertNotEqual(words[2], error)
        }
    }
}
