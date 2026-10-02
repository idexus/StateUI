// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import CStateUIAndroid
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
@_spi(Host) import StateUIConformance

/// What the Android driver reads of a member's value: from the view Android holds - a control's state, a view's
/// transform, its node's words as TalkBack reads them - never from what the host last wrote.
/// Design: docs/design/platforms/android/conformance.md#what-the-driver-reads
extension AndroidDriver {
    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? {
        if element.type == .menuItem || element.type == .toolbarItem { return try itemHolds(property, element) }
        if property == .barSubtitle || property == .barBackgroundColor { return Self.barHolds(property, of: element) }
        let view = (element.native as? AndroidElement)?.view
        if let field = view as? AndroidDateFieldView, let held = try Self.dateFieldHolds(property, field) { return held }
        if let web = view as? AndroidWebView, let held = try Self.webHolds(property, web) { return held }
        switch (property, view) {
        case (.isOn, let toggle as AndroidToggleView): return toggle.isOn.propValue
        case (.value, let slider as AndroidSliderView): return slider.value.propValue
        case (.minimum, let slider as AndroidSliderView): return slider.minimum.propValue
        case (.maximum, let slider as AndroidSliderView): return slider.maximum.propValue
        case (.value, let stepper as AndroidStepperView): return stepper.value.propValue
        case (.progress, let bar as AndroidProgressBarView): return bar.progress.propValue
        case (.showsSidebar, let split as AndroidSplitView): return split.isPresented.propValue
        case (.selectedItems, let items as AndroidItemsView): return .strings(items.selectedForTesting)
        case (.selectionMode, let items as AndroidItemsView): return items.modeForTesting.propValue
        case (.isAnimating, let spinner as AndroidActivityIndicatorView):
            // A spinner that runs is visible; one that stopped is invisible, and the host keeps no other trace.
            return (Java.callInt(spinner.reference, JavaAPI.getVisibility) == 0).propValue
        case (.text, let text as AndroidTextualView): return text.text.propValue
        // The return key as the field asks the keyboard for it: EditorInfo's actions, as the host writes them.
        case (.submitLabel, let field as AndroidTextFieldView):
            let action = Java.callInt(field.reference, Self.getImeOptions) & 0xff
            let key: SubmitLabel = switch action {
            case 2: .go
            case 3: .search
            case 4: .send
            case 5: .next
            case 6: .done
            default: .default
            }
            return key.propValue
        // Read only: the field offers a keyboard nothing to edit.
        case (.isReadOnly, let field as AndroidTextFieldView):
            return (!Java.callBool(field.reference, Self.onCheckIsTextEditor)).propValue
        case (.fontSize, let text as AndroidTextualView):
            return Double(Java.callStaticFloat(Self.testText, Self.points, .object(text.reference))).rounded().propValue
        case (.fontAttributes, let text as AndroidTextualView):
            return FontAttributes(rawValue: Java.callStaticInt(Self.testText, Self.style, .object(text.reference)) & 3)
                .propValue
        case (.textColor, let text as AndroidTextualView):
            return Self.color(UInt32(bitPattern: Java.callInt(text.reference, Self.getCurrentTextColor))).propValue
        case (.background, let view?):
            let held = Java.callStaticLong(Self.testPixels, Self.background, .object(view.reference))
            guard held >> 32 == 1 else { throw DriverCannot("read a background of no one colour") }
            return Background.color(Self.color(UInt32(truncatingIfNeeded: held))).propValue
        case (.options, let picker as AndroidPickerView): return Array(Self.rows(of: picker).dropFirst()).propValue
        case (.title, let picker as AndroidPickerView): return Self.rows(of: picker).first?.propValue
        case (.selectedIndex, let picker as AndroidPickerView):
            // The title's row stands first: it is no choice.
            return (Int(Java.callInt(picker.reference, Self.getSelectedItemPosition)) - 1).propValue
        case (.fontFamily, _ as AndroidTextualView):
            throw DriverCannot("read a family", because: "Android's typeface keeps no family's name")
        case (_, let view?):
            if let held = try Self.viewHolds(property, view) { return held }
            throw DriverCannot(reading: property, of: element)
        default: throw DriverCannot(reading: property, of: element)
        }
    }

    /// What every view holds: whether it shows, how opaque it is, whether it takes input, how it is moved, and what
    /// assistive technology meets - its node's words, as TalkBack reads them.
    private static func viewHolds(_ property: Prop, _ view: AndroidView) throws -> HostValue? {
        let reference = view.reference
        let float = { (method: jmethodID) in Double(Java.callFloat(reference, method)) }
        switch property {
        // Shown: attached to a window, and neither it nor any view it stands in hidden.
        case .isVisible: return Java.callBool(reference, isShown).propValue
        case .opacity: return float(getAlpha).propValue
        case .isEnabled: return Java.callBool(reference, isEnabled).propValue
        // The direction Android resolved for the view: LAYOUT_DIRECTION_RTL is 1.
        case .layoutDirection:
            return (Java.callInt(reference, getLayoutDirection) == 1 ? LayoutDirection.rightToLeft : .leftToRight).propValue
        case .translationX: return (float(getTranslationX) / 2).propValue
        case .translationY: return (float(getTranslationY) / 2).propValue
        case .rotation: return float(getRotation).propValue
        case .rotationX: return float(getRotationX).propValue
        case .rotationY: return float(getRotationY).propValue
        case .scaleX: return float(getScaleX).propValue
        case .scaleY: return float(getScaleY).propValue
        case .scale:
            let (across, down) = (float(getScaleX), float(getScaleY))
            return (across == down ? across : 1).propValue
        case .pivotX:
            // A share of the view's size, which Android keeps in pixels.
            let width = Double(view.frame.width)
            return (width > 0 ? float(getPivotX) / width : 0.5).propValue
        case .pivotY:
            let height = Double(view.frame.height)
            return (height > 0 ? float(getPivotY) / height : 0.5).propValue
        case .accessibilityLabel: return TestAccessibility.word("label", of: view).propValue
        case .accessibilityHint: return TestAccessibility.word("hint", of: view).propValue
        case .accessibilityIdentifier: return TestAccessibility.word("id", of: view).propValue
        case .isAccessibilityHidden:
            let presence = Java.callInt(reference, JavaAPI.getImportantForAccessibility)
            return (presence == 2 || presence == 4).propValue
        case .automationExcludedWithChildren:
            return (Java.callInt(reference, JavaAPI.getImportantForAccessibility) == 4).propValue
        case .accessibilityHeading:
            throw DriverCannot("read a heading's level", because: "Android marks a heading, not its level")
        default: return controlHolds(property, view)
        }
    }


    static let isShown = Java.method(JavaAPI.view, "isShown", "()Z")
    static let getLayoutDirection = Java.method(JavaAPI.view, "getLayoutDirection", "()I")
    static let onCheckIsTextEditor = Java.method(JavaAPI.view, "onCheckIsTextEditor", "()Z")
    static let getImeOptions = Java.method(JavaAPI.textView, "getImeOptions", "()I")
    static let getTranslationX = Java.method(JavaAPI.view, "getTranslationX", "()F")
    static let getTranslationY = Java.method(JavaAPI.view, "getTranslationY", "()F")
    static let getRotation = Java.method(JavaAPI.view, "getRotation", "()F")
    static let getRotationX = Java.method(JavaAPI.view, "getRotationX", "()F")
    static let getRotationY = Java.method(JavaAPI.view, "getRotationY", "()F")
    static let getScaleX = Java.method(JavaAPI.view, "getScaleX", "()F")
    static let getScaleY = Java.method(JavaAPI.view, "getScaleY", "()F")
    static let getPivotX = Java.method(JavaAPI.view, "getPivotX", "()F")
    static let getPivotY = Java.method(JavaAPI.view, "getPivotY", "()F")
    static let testText = Java.findClass("stateui/android/test/TestText")
    static let points = Java.staticMethod(testText, "points", "(Landroid/widget/TextView;)F")
    static let style = Java.staticMethod(testText, "style", "(Landroid/widget/TextView;)I")
    static let getCurrentTextColor = Java.method(JavaAPI.textView, "getCurrentTextColor", "()I")

    /// A picker's rows' words as its spinner shows them, the title's first.
    private static func rows(of picker: AndroidPickerView) -> [String] {
        Java.frame {
            guard let rows = Java.callStaticObject(testPicker, pickerRows, .object(picker.reference)) else { return [] }
            return (0..<Java.jni.GetArrayLength(Java.env, rows)).map { index in
                Java.jni.GetObjectArrayElement(Java.env, rows, index).map { Java.text($0) } ?? ""
            }
        }
    }

    /// A colour Android holds as 0xAARRGGBB.
    static func color(_ argb: UInt32) -> Color {
        Color(red: Int(argb >> 16 & 0xFF), green: Int(argb >> 8 & 0xFF), blue: Int(argb & 0xFF), alpha: Int(argb >> 24))
    }

    static let testPixels = Java.findClass("stateui/android/test/TestPixels")
    static let background = Java.staticMethod(testPixels, "background", "(Landroid/view/View;)J")
    static let pixel = Java.staticMethod(testPixels, "color", "(Landroid/view/View;II)I")
    static let paintNothing = Java.staticMethod(testPixels, "paintNothing", "(Landroid/app/Activity;)V")
}
