// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

extension NSAttributedString {
    /// A field's placeholder in `color`, standing where `alignment` puts the field's own words.
    /// Design: docs/design/platforms/appkit/views.md#a-fields-placeholder
    static func placeholder(_ text: String, color: NSColor, alignment: NSTextAlignment) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        return NSAttributedString(string: text, attributes: [.foregroundColor: color, .paragraphStyle: paragraph])
    }
}
#endif
