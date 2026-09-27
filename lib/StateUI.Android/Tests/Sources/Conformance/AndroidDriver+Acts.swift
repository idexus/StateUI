// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import CStateUIAndroid
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
@_spi(Host) import StateUIConformance

/// What the Android driver does as the user: a click, a toggle, words typed, a dialog answered, the activity's
/// lifecycle, and a finger's or a mouse's input as the view's own touches and hovering take it - motion events
/// dispatched to the view, in its pixels.
/// Design: docs/design/platforms/android/conformance.md#what-the-driver-does
extension AndroidDriver {
    func perform(_ act: UserAct, on element: MountedElement) throws {
        let view = (element.native as? AndroidElement)?.view
        switch (act, view) {
        case (.activate, let button as AndroidButtonView): button.click()
        case (.toggle, let toggle as AndroidToggleView): toggle.click()
        case (.toggle, let split as AndroidSplitView):
            // The scrim's tap hides the sidebar, the bar's button shows it: both the host's own entry.
            (element.native as? AndroidElement)?.changeSidebarVisibility(to: !split.isPresented)
        case (.type(let words), let field as AndroidTextFieldView): Self.type(words, into: field)
        case (.submit, let field as AndroidTextFieldView):
            // The keyboard's own action, as the field's return key says it: done, or search for a search field.
            Java.call(field.reference, Self.onEditorAction, .int(element.type == .searchField ? 3 : 6))
        case (.answer(let caption, let words), _):
            let answered = Java.frame {
                Java.callStaticBool(
                    Self.dialogs, Self.answer, .object(Java.string(caption)), .object(words.flatMap(Java.string)))
            }
            guard answered else { throw DriverCannot("answer by \(caption)") }
        case (.choose(let place), let picker as AndroidPickerView):
            // The row after the title's, as the user's tap on it in the open list chooses it.
            Java.callStatic(Self.testPicker, Self.choosePicker, .object(picker.reference), .int(Int32(place + 1)))
        case (.tap(let count), let view?): Self.tap(view, count: count)
        case (.pan(let offset), let view?): Self.pan(view, by: offset)
        case (.pinch(let scale, let point), let view?):
            let (width, height) = (Float(view.frame.width), Float(view.frame.height))
            TestTouches.pinch(view, x: Float(point.x) * width, y: Float(point.y) * height, by: Float(scale))
        case (.pressDown(let point), let view?): view.touch(Self.down, x: Self.pixels(point.x), y: Self.pixels(point.y))
        case (.drag(let point), let view?): view.touch(Self.move, x: Self.pixels(point.x), y: Self.pixels(point.y))
        case (.lift(let point), let view?): view.touch(Self.up, x: Self.pixels(point.x), y: Self.pixels(point.y))
        case (.hover(let point), let view?):
            TestTouches.hover(view, action: Self.hoverEnter, x: Self.pixels(point.x), y: Self.pixels(point.y))
            TestTouches.hover(view, action: Self.hoverMove, x: Self.pixels(point.x), y: Self.pixels(point.y))
        case (.leave, let view?): TestTouches.hover(view, action: Self.hoverExit, x: 0, y: 0)
        case (.switchAway, _) where element.type == .window: renderer?.setPhase(.inactive)
        case (.switchBack, _) where element.type == .window: renderer?.setPhase(.active)
        case (.minimize, _) where element.type == .window:
            renderer?.setPhase(.inactive)
            renderer?.setPhase(.background)
        case (.restore, _) where element.type == .window: renderer?.setPhase(.active)
        case (.close, _) where element.type == .window:
            renderer?.setPhase(.inactive)
            renderer?.setPhase(.background)
            renderer?.destroying()
        default: throw DriverCannot(act, on: element)
        }
    }

    /// A quick run of `count` taps in the middle of `view`, each put down and lifted soon after the last.
    private static func tap(_ view: AndroidView, count: Int) {
        let (x, y) = (Float(view.frame.width) / 2, Float(view.frame.height) / 2)
        for run in 0..<Int64(max(count, 1)) {
            view.touch(down, x: x, y: y, at: run * 150)
            view.touch(up, x: x, y: y, at: run * 150 + 50)
        }
    }

    /// A finger put down in the middle of `view`, moved by `offset` points in two steps, and lifted.
    private static func pan(_ view: AndroidView, by offset: Point) {
        let (x, y) = (Float(view.frame.width) / 2, Float(view.frame.height) / 2)
        let (across, down) = (pixels(offset.x), pixels(offset.y))
        view.touch(Self.down, x: x, y: y, at: 0)
        view.touch(move, x: x + across / 2, y: y + down / 2, at: 20)
        view.touch(move, x: x + across, y: y + down, at: 40)
        view.touch(up, x: x + across, y: y + down, at: 60)
    }

    /// `points` in the driver's pixels, two a point.
    private static func pixels(_ points: Double) -> Float {
        Float(points * 2)
    }

    static let testPicker = Java.findClass("stateui/android/test/TestPicker")
    static let choosePicker = Java.staticMethod(testPicker, "choose", "(Landroid/widget/Spinner;I)V")
    static let pickerRows = Java.staticMethod(testPicker, "rows", "(Landroid/widget/Spinner;)[Ljava/lang/String;")
    static let getSelectedItemPosition = Java.method(
        Java.findClass("android/widget/AdapterView"), "getSelectedItemPosition", "()I")

    /// A motion event's actions, as Android numbers them.
    private static let (down, up, move) = (Int32(0), Int32(1), Int32(2))
    private static let (hoverMove, hoverEnter, hoverExit) = (Int32(7), Int32(9), Int32(10))

    /// Types `words` as the whole of a field's words, as the keyboard edits them: the field's own words replaced in
    /// its editable text, which its watcher hears as it hears a key.
    private static func type(_ words: String, into field: AndroidTextFieldView) {
        let editable = Java.callObject(field.reference, JavaAPI.getText)!
        let text = Java.string(words)
        let length = Java.callInt(editable, length)
        Java.release(local: Java.callObject(editable, replace, .int(0), .int(length), .object(text)))
        Java.release(local: text)
        Java.release(local: editable)
    }

}
