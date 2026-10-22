// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance

/// What the UIKit driver reads of every view: its transform as its layer holds it, what VoiceOver meets, a control's
/// font and words' color, and the color behind it - each from UIKit itself.
/// Design: docs/design/platforms/uikit/conformance.md#what-the-driver-reads
extension UIKitDriver {
    /// The view VoiceOver meets for `view`: the control a wrapping view presents - a switch beside its words - else
    /// the view itself.
    static func met(_ view: UIView) -> UIView {
        (view as? UIKitAccessibilityPresenting)?.presentedControl ?? view
    }

    static func viewHolds(_ property: Prop, _ view: UIView, _ native: UIKitElement?) throws -> HostValue? {
        switch property {
        case .translationX, .translationY, .rotation, .rotationX, .rotationY, .scale, .scaleX, .scaleY, .pivotX,
             .pivotY:
            guard let drawn = native?.drawing?.heldTransformForTesting else {
                throw DriverCannot("read a transform: the view's layer holds another")
            }
            return transform(property, drawn)
        case .accessibilityLabel: return met(view).accessibilityLabel.propValue
        case .accessibilityHint: return met(view).accessibilityHint.propValue
        case .accessibilityRole:
            let traits = met(view).accessibilityTraits
            // A kind said stands alone among the traits saying a kind.
            let kinds = AccessibilityRole.allCases.filter { traits.contains(UIKitElement.accessibilityTrait($0)) }
            return kinds.count == 1 ? kinds[0].propValue : nil
        case .accessibilityValue: return met(view).accessibilityValue.propValue
        case .accessibilityIdentifier: return met(view).accessibilityIdentifier.propValue
        case .isAccessibilityHidden: return (!met(view).isAccessibilityElement).propValue
        case .hidesChildrenFromAccessibility:
            return (!met(view).isAccessibilityElement && met(view).accessibilityElementsHidden).propValue
        case .accessibilityHeading:
            throw DriverCannot("read a heading's level", because: "UIKit marks a heading, not its level")
        case .keyboardShortcut:
            // The key command the window offers that reaches this element.
            guard let native, let root = UIKitDriver.windowRoot(of: native.element) else { return nil }
            let window = native.element.enclosing(type: .window) ?? native.element
            return root.keyCommands?.compactMap { UIKitKeys.shortcut(of: $0) }
                .first { KeyboardShortcuts.target(of: $0, under: window) === native.element }?.propValue
        case .fontSize, .fontWeight, .fontAttributes, .fontFamily, .textColor, .tracking, .lineHeight, .textDecorations:
            return try words(property, view)
        case .isFontAutoScalingEnabled:
            return try scales(view) { try words(.fontSize, view)?.number ?? 0 }.propValue
        case .background:
            if let held = try controlHolds(property, view) { return held }
            return view.backgroundColor.map { StandIns.material(painted: color($0)).propValue }
        default:
            return try controlHolds(property, view)
        }
    }

    private static func transform(_ property: Prop, _ drawn: HostDrawingTransform) -> HostValue? {
        switch property {
        case .translationX: drawn.translationX.propValue
        case .translationY: drawn.translationY.propValue
        case .rotation: drawn.rotation.propValue
        case .rotationX: drawn.rotationX.propValue
        case .rotationY: drawn.rotationY.propValue
        case .scale: (drawn.scaleX == drawn.scaleY ? drawn.scaleX : 1).propValue
        case .scaleX: drawn.scaleX.propValue
        case .scaleY: drawn.scaleY.propValue
        case .pivotX: drawn.pivotX.propValue
        case .pivotY: drawn.pivotY.propValue
        default: nil
        }
    }

    /// What `font` draws beyond its size, weight and family: its slant, and its digits of one width.
    static func attributes(of font: UIFont) -> FontAttributes {
        var attributes = FontAttributes.none
        if font.fontDescriptor.symbolicTraits.contains(.traitItalic) { attributes.insert(.italic) }
        let features = font.fontDescriptor.object(forKey: .featureSettings) as? [[UIFontDescriptor.FeatureKey: Int]]
        if features?.contains(where: { $0[.type] == kNumberSpacingType && $0[.selector] == kMonospacedNumbersSelector })
            == true { attributes.insert(.monospacedDigits) }
        return attributes
    }

    /// A control's words as UIKit draws them: their font's size, bold and italic, family, and their color.
    private static func words(_ property: Prop, _ shown: UIView) throws -> HostValue? {
        // A switch's words are its label's.
        let view = (shown as? UIKitSwitchView)?.caption ?? shown
        view.layoutIfNeeded()
        let written = (view as? UILabel)?.attributedText ?? (view as? UIButton)?.titleLabel?.attributedText
            ?? (view as? UITextView)?.attributedText
        let first = written.flatMap { $0.length > 0 ? $0.attributes(at: 0, effectiveRange: nil) : nil }
        let drawn: (font: UIFont?, color: UIColor?) = switch view {
        case let label as UILabel:
            (first?[.font] as? UIFont ?? label.font, first?[.foregroundColor] as? UIColor ?? label.textColor)
        case let field as UITextField: (field.font, field.textColor)
        case let editor as UITextView: (editor.font, editor.textColor)
        case let button as UIButton: (button.titleLabel?.font, button.titleLabel?.textColor)
        default: (nil, nil)
        }
        guard let font = drawn.font else { throw DriverCannot("read the words of a \(type(of: view))") }
        switch property {
        case .fontSize: return Double(font.pointSize).propValue
        case .fontFamily: return Name(font.familyName).propValue
        case .fontWeight: return FontWeight(uiKit: font.weight).propValue
        case .fontAttributes: return attributes(of: font).propValue
        case .textColor: return drawn.color.map { color($0).propValue }
        case .tracking:
            guard written != nil else { throw DriverCannot("read the spacing of a \(type(of: view))") }
            return ((first?[.kern] as? Double) ?? 0).propValue
        case .lineHeight:
            guard written != nil else { throw DriverCannot("read the lines of a \(type(of: view))") }
            let multiple = (first?[.paragraphStyle] as? NSParagraphStyle)?.lineHeightMultiple ?? 0
            return multiple > 0 ? Double(multiple).propValue : nil
        case .textDecorations:
            guard written != nil else { throw DriverCannot("read the lines of a \(type(of: view))") }
            var decorations: TextDecorations = []
            if first?[.underlineStyle] != nil { decorations.insert(.underline) }
            if first?[.strikethroughStyle] != nil { decorations.insert(.strikethrough) }
            return decorations.propValue
        default: return nil
        }
    }

    /// Whether words grow with the user's text size: the `size` they stand at under the largest the user can choose,
    /// beside the one they stand at now - the view's own text size given back after.
    static func scales(_ view: UIView, size: () throws -> Double) throws -> Bool {
        let standing = try size()
        view.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        defer {
            view.traitOverrides.remove(UITraitPreferredContentSizeCategory.self)
            view.updateTraitsIfNeeded()
            view.layoutIfNeeded()
        }
        view.updateTraitsIfNeeded()
        view.layoutIfNeeded()
        return try size() > standing
    }

    /// A color UIKit holds, in sRGB, as StateUI's.
    static func color(_ native: UIColor) -> Color {
        var (red, green, blue, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        native.resolvedColor(with: UITraitCollection.current).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func channel(_ value: CGFloat) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return Color(red: channel(red), green: channel(green), blue: channel(blue), alpha: channel(alpha))
    }
}
