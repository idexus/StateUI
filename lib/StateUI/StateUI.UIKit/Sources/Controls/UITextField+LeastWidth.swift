// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUIHost

extension UITextField {
    /// How wide the field asks to be where nothing sizes it - its placeholder, or twenty digits, in its font, with
    /// the room it keeps around its words - where UIKit's own asks for less.
    /// Design: docs/design/host/layout.md#a-fields-own-width
    func leastWidth(own: CGFloat) -> CGFloat {
        let font = font ?? .preferredFont(forTextStyle: .body)
        let measured = FieldWidth.leastWords(placeholder: attributedPlaceholder?.string ?? placeholder).map {
            Double(($0 as NSString).size(withAttributes: [.font: font]).width.rounded(.up))
        }
        let probe = CGRect(x: 0, y: 0, width: 1000, height: 100)
        let chrome = Double(probe.width - textRect(forBounds: probe).width)
        return CGFloat(FieldWidth.width(own: own == UIView.noIntrinsicMetric ? nil : Double(own), measured: measured,
                                        chrome: chrome))
    }
}
#endif
