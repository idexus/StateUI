// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance

/// What the UIKit driver reads of every view: its transform as its layer holds it, what VoiceOver meets, a control's
/// font and words' colour, and the colour behind it - each from UIKit itself.
/// Design: docs/design/platforms/uikit/conformance.md#what-the-driver-reads
extension UIKitDriver {
    static func viewHolds(_ property: Prop, _ view: UIView, _ native: UIKitElement?) throws -> HostValue? {
        switch property {
        case .translationX, .translationY, .rotation, .rotationX, .rotationY, .scale, .scaleX, .scaleY, .pivotX,
             .pivotY:
            guard let drawn = native?.drawing?.heldTransformForTesting else {
                throw DriverCannot("read a transform: the view's layer holds another")
            }
            return transform(property, drawn)
        case .accessibilityLabel: return view.accessibilityLabel.propValue
        case .accessibilityHint: return view.accessibilityHint.propValue
        case .accessibilityIdentifier: return view.accessibilityIdentifier.propValue
        case .isAccessibilityHidden: return (!view.isAccessibilityElement).propValue
        case .automationExcludedWithChildren:
            return (!view.isAccessibilityElement && view.accessibilityElementsHidden).propValue
        case .accessibilityHeadingLevel:
            throw DriverCannot("read a heading's level: UIKit marks a heading, not its level")
        case .fontSize, .fontAttributes, .fontFamily, .textColor:
            return try words(property, view)
        case .background:
            return view.backgroundColor.map { Background.color(color($0)).propValue }
        default:
            return nil
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

    /// A control's words as UIKit draws them: their font's size, bold and italic, family, and their colour.
    private static func words(_ property: Prop, _ view: UIView) throws -> HostValue? {
        view.layoutIfNeeded()
        let drawn: (font: UIFont?, color: UIColor?) = switch view {
        case let label as UILabel: (label.font, label.textColor)
        case let field as UITextField: (field.font, field.textColor)
        case let button as UIButton: (button.titleLabel?.font, button.titleLabel?.textColor)
        default: (nil, nil)
        }
        guard let font = drawn.font else { throw DriverCannot("read the words of a \(type(of: view))") }
        switch property {
        case .fontSize: return Double(font.pointSize).propValue
        case .fontFamily: return Name(font.familyName).propValue
        case .fontAttributes:
            let traits = font.fontDescriptor.symbolicTraits
            var attributes: FontAttributes = []
            if traits.contains(.traitBold) { attributes.insert(.bold) }
            if traits.contains(.traitItalic) { attributes.insert(.italic) }
            return attributes.propValue
        case .textColor: return drawn.color.map { color($0).propValue }
        default: return nil
        }
    }

    /// A colour UIKit holds, in sRGB, as StateUI's.
    static func color(_ native: UIColor) -> Color {
        var (red, green, blue, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        native.resolvedColor(with: UITraitCollection.current).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func channel(_ value: CGFloat) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return Color(red: channel(red), green: channel(green), blue: channel(blue), alpha: channel(alpha))
    }
}
