// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIFont {
    /// The platform's own text size, before the user's.
    private static let platformSize = UITraitCollection(preferredContentSizeCategory: .large)

    /// The body's font at the platform's own text size.
    private static let body = UIFont.preferredFont(forTextStyle: .body, compatibleWith: platformSize)

    /// The font a StateUI look asks for: its style's from UIKit's type ramp - the body's where it names none - the
    /// size and weight it gives over the style's, its family - the system's where it names none, or none such is
    /// installed - italic as its slant says, and grown with the user's text size in `traits` as its style grows where
    /// the look scales.
    /// Design: docs/design/platforms/uikit/controls.md#a-text-style
    static func stateUI(_ look: TextLook, in traits: UITraitCollection = .current) -> UIFont {
        let font = unscaled(look)
        let metrics = UIFontMetrics(forTextStyle: look.style?.uiKit ?? .body)
        return look.scales ? metrics.scaledFont(for: font, compatibleWith: traits) : font
    }

    private static func unscaled(_ look: TextLook) -> UIFont {
        let styled = look.style.map { UIFont.preferredFont(forTextStyle: $0.uiKit, compatibleWith: platformSize) }
        let (size, weight) = look.standing(
            styleSize: styled.map { Double($0.pointSize) }, styleWeight: styled.map { FontWeight(uiKit: $0.weight) })
        let points = CGFloat(size ?? Double(body.pointSize))
        let thickness = weight?.uiKit ?? .regular
        let base = look.family.flatMap { UIFont(name: $0, size: points) }.map { named in
            UIFont(descriptor: named.fontDescriptor.addingAttributes([
                .traits: [UIFontDescriptor.TraitKey.weight: thickness],
            ]), size: points)
        } ?? UIFont.systemFont(ofSize: points, weight: thickness)
        guard look.attributes.contains(.italic),
              let descriptor = base.fontDescriptor.withSymbolicTraits(base.fontDescriptor.symbolicTraits.union(.traitItalic))
        else { return base }
        return UIFont(descriptor: descriptor, size: points)
    }

    /// How heavy the font's strokes are, as its descriptor says; regular where it says nothing.
    var weight: UIFont.Weight {
        let traits = fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        return UIFont.Weight((traits?[.weight] as? CGFloat) ?? 0)
    }
}

extension TextStyle {
    /// UIKit's step of its type ramp for the style.
    var uiKit: UIFont.TextStyle {
        switch self {
        case .display: .largeTitle
        case .title: .title1
        case .subtitle: .title2
        case .headline: .headline
        case .body: .body
        case .caption: .caption1
        }
    }
}

extension FontWeight {
    /// UIKit's weight for it.
    var uiKit: UIFont.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }

    /// The weight nearest UIKit's `weight`.
    init(uiKit weight: UIFont.Weight) {
        let steps = FontWeight.allCases.map { abs($0.uiKit.rawValue - weight.rawValue) }
        self = FontWeight.allCases[steps.firstIndex(of: steps.min() ?? 0) ?? 0]
    }
}
#endif
