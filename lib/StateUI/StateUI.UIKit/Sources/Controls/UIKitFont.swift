// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIFont {
    /// The body's font at the platform's own text size, before the user's.
    private static let body = UIFont.preferredFont(
        forTextStyle: .body, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))

    /// The font a StateUI look asks for: its family - the system's where it names none, or none such is installed -
    /// its size in points - the body's where it says none - bold and italic as its attributes say, and grown with
    /// the user's text size in `traits` where the look scales.
    static func stateUI(_ look: TextLook, in traits: UITraitCollection = .current) -> UIFont {
        let font = unscaled(look)
        return look.scales ? UIFontMetrics(forTextStyle: .body).scaledFont(for: font, compatibleWith: traits) : font
    }

    private static func unscaled(_ look: TextLook) -> UIFont {
        let size = CGFloat(look.size ?? Double(body.pointSize))
        let base = look.family.flatMap { UIFont(name: $0, size: size) }
            ?? UIFont.systemFont(ofSize: size, weight: look.attributes.contains(.bold) ? .bold : .regular)
        var traits = base.fontDescriptor.symbolicTraits
        if look.attributes.contains(.bold) { traits.insert(.traitBold) }
        if look.attributes.contains(.italic) { traits.insert(.traitItalic) }
        guard let descriptor = base.fontDescriptor.withSymbolicTraits(traits) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}
#endif
