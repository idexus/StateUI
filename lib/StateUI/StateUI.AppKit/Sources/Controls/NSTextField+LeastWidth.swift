// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUIHost

extension NSTextField {
    /// How wide the field asks to be where nothing sizes it - its placeholder, or twenty digits, in its font, with
    /// the room its cell keeps around its words - where AppKit's own asks for no width or less.
    /// Design: docs/design/host/layout.md#a-fields-own-width
    func leastWidth(own: CGFloat) -> CGFloat {
        let font = font ?? .systemFont(ofSize: NSFont.systemFontSize)
        let placeholder = placeholderAttributedString?.string ?? placeholderString
        let measured = FieldWidth.leastWords(placeholder: placeholder).map {
            Double(($0 as NSString).size(withAttributes: [.font: font]).width.rounded(.up))
        }
        let probe = NSRect(x: 0, y: 0, width: 1000, height: 100)
        let words = (cell as? NSSearchFieldCell)?.searchTextRect(forBounds: probe) ?? cell?.drawingRect(forBounds: probe)
        // The text container's line fragment pads the words on both sides.
        let chrome = Double(probe.width - (words?.width ?? probe.width)) + 4
        return CGFloat(FieldWidth.width(own: own == NSView.noIntrinsicMetric ? nil : Double(own), measured: measured,
                                        chrome: chrome))
    }
}
#endif
