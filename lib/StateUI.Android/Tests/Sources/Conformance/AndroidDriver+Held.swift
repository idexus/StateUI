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
        let view = (element.native as? AndroidElement)?.view
        switch (property, view) {
        case (.isOn, let toggle as AndroidToggleView): return toggle.isOn.propValue
        case (.value, let slider as AndroidSliderView): return slider.value.propValue
        case (.minimum, let slider as AndroidSliderView): return slider.minimum.propValue
        case (.maximum, let slider as AndroidSliderView): return slider.maximum.propValue
        case (.value, let stepper as AndroidStepperView): return stepper.value.propValue
        case (.progress, let bar as AndroidProgressBarView): return bar.progress.propValue
        case (.isRunning, let spinner as AndroidActivityIndicatorView): return spinner.isRunning.propValue
        case (.text, let text as AndroidTextView): return text.text.propValue
        case (.fontSize, let text as AndroidTextView):
            return Double(Java.callStaticFloat(Self.testText, Self.points, .object(text.reference))).rounded().propValue
        case (.fontAttributes, let text as AndroidTextView):
            return FontAttributes(rawValue: Java.callStaticInt(Self.testText, Self.style, .object(text.reference)) & 3)
                .propValue
        case (.textColor, let text as AndroidTextView):
            let argb = UInt32(bitPattern: Java.callInt(text.reference, Self.getCurrentTextColor))
            return Color(
                red: Int(argb >> 16 & 0xFF), green: Int(argb >> 8 & 0xFF), blue: Int(argb & 0xFF),
                alpha: Int(argb >> 24)).propValue
        case (.fontFamily, _ as AndroidTextView):
            throw DriverCannot("read a family: Android's typeface keeps no family's name")
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
        case .isVisible: return (Java.callInt(reference, JavaAPI.getVisibility) == 0).propValue
        case .opacity: return float(getAlpha).propValue
        case .isEnabled: return Java.callBool(reference, isEnabled).propValue
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
        case .accessibilityHeadingLevel:
            throw DriverCannot("read a heading's level: Android marks a heading, not its level")
        default: return nil
        }
    }


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
}
