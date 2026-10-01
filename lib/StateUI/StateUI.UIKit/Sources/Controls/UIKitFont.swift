// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIFont {
    /// The font a StateUI look asks for: its family - the system's where it names none, or none such is installed -
    /// its size in points - `standing`'s where it says none - and bold and italic as its attributes say.
    static func stateUI(_ look: TextLook, standing: UIFont) -> UIFont {
        let size = CGFloat(look.size ?? Double(standing.pointSize))
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
