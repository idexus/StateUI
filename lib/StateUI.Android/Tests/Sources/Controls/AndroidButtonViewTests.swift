// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import CStateUIAndroid
import XCTest

final class AndroidButtonViewTests: XCTestCase {
    static var allTests: [(String, (AndroidButtonViewTests) -> () throws -> Void)] {
        [
            ("testAButtonIsAsBigAsItsWordsAndItsRoom", testAButtonIsAsBigAsItsWordsAndItsRoom),
            ("testAnIconAloneFitsTheRoomInsideThePadding", testAnIconAloneFitsTheRoomInsideThePadding),
            ("testAnIconBesideWordsStandsWhereItsPositionSays", testAnIconBesideWordsStandsWhereItsPositionSays),
            ("testALookIsOneShapeUnderThePlatformsRipple", testALookIsOneShapeUnderThePlatformsRipple),
            ("testADisabledLookDimsAsTheThemesControlsDo", testADisabledLookDimsAsTheThemesControlsDo),
            ("testAFingerDownAndUpArePressedAndReleased", testAFingerDownAndUpArePressedAndReleased),
            ("testAFamilyChangesTheTypeface", testAFamilyChangesTheTypeface),
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

    /// The pixels of padding around the button's words, across and down.
    @MainActor
    private static func padding(of button: AndroidButtonView) -> (width: Int32, height: Int32) {
        let reference = button.reference
        return (
            Java.callInt(reference, JavaAPI.getPaddingLeft) + Java.callInt(reference, JavaAPI.getPaddingRight),
            Java.callInt(reference, JavaAPI.getPaddingTop) + Java.callInt(reference, JavaAPI.getPaddingBottom)
        )
    }
}
