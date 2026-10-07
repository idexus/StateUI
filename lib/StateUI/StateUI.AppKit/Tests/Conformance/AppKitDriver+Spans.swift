// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAppKit
@_spi(Host) import StateUIConformance

/// What the AppKit driver reads of a run of a text's words: the part of its label's words the run stands over
/// (`RunPlace`), and the attributes AppKit draws there.
/// Design: docs/design/platforms/appkit/conformance.md#what-the-driver-reads
extension AppKitDriver {
    func spanHolds(_ property: Prop, on span: MountedElement) throws -> HostValue? {
        guard let place = RunPlace(of: span), let label = (place.text.native as? AppKitElement)?.view as? AppKitTextView,
              place.range.upperBound <= label.attributedStringValue.length
        else { throw DriverCannot(reading: property, of: span) }
        let words = label.attributedStringValue
        let range = NSRange(location: place.range.lowerBound, length: place.range.count)
        let attributes = range.length > 0 ? words.attributes(at: range.location, effectiveRange: nil) : [:]
        guard let font = attributes[.font] as? NSFont else { throw DriverCannot(reading: property, of: span) }
        switch property {
        case .text: return (words.string as NSString).substring(with: range).propValue
        case .fontSize: return Double(font.pointSize).propValue
        case .fontFamily: return font.familyName.map { Name($0) }.propValue
        case .fontAttributes:
            let traits = NSFontManager.shared.traits(of: font)
            var held: FontAttributes = []
            if traits.contains(.boldFontMask) { held.insert(.bold) }
            if traits.contains(.italicFontMask) { held.insert(.italic) }
            return held.propValue
        case .textColor: return (attributes[.foregroundColor] as? NSColor).map { Self.color($0).propValue }
        case .background: return (attributes[.backgroundColor] as? NSColor).map { Self.color($0).propValue }
        case .tracking: return Double((attributes[.kern] as? NSNumber)?.doubleValue ?? 0).propValue
        case .textDecorations:
            var decorations: TextDecorations = []
            if (attributes[.underlineStyle] as? Int ?? 0) != 0 { decorations.insert(.underline) }
            if (attributes[.strikethroughStyle] as? Int ?? 0) != 0 { decorations.insert(.strikethrough) }
            return decorations.propValue
        default: throw DriverCannot(reading: property, of: span)
        }
    }
}
#endif
