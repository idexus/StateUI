// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance

/// What the UIKit driver reads of a run of a text's words: the part of its label's words the run stands over
/// (`RunPlace`), and the attributes UIKit draws there - the label's own font and colour where the run has none.
/// Design: docs/design/platforms/uikit/conformance.md#what-the-driver-reads
extension UIKitDriver {
    func spanHolds(_ property: Prop, on span: MountedElement) throws -> HostValue? {
        guard let place = RunPlace(of: span), let label = (place.text.native as? UIKitElement)?.view as? UILabel,
              let words = label.attributedText, place.range.upperBound <= words.length
        else { throw DriverCannot(reading: property, of: span) }
        let range = NSRange(location: place.range.lowerBound, length: place.range.count)
        let attributes = range.length > 0 ? words.attributes(at: range.location, effectiveRange: nil) : [:]
        let font = attributes[.font] as? UIFont ?? label.font!
        switch property {
        case .text: return (words.string as NSString).substring(with: range).propValue
        case .fontSize: return Double(font.pointSize).propValue
        case .isFontAutoScalingEnabled:
            return try Self.scales(label) {
                let words = label.attributedText ?? NSAttributedString()
                guard range.upperBound <= words.length else { throw DriverCannot(reading: property, of: span) }
                return Double((words.attributes(at: range.location, effectiveRange: nil)[.font] as? UIFont ?? label.font!).pointSize)
            }.propValue
        case .fontFamily: return Name(font.familyName).propValue
        case .fontAttributes:
            let traits = font.fontDescriptor.symbolicTraits
            var held: FontAttributes = []
            if traits.contains(.traitBold) { held.insert(.bold) }
            if traits.contains(.traitItalic) { held.insert(.italic) }
            return held.propValue
        case .textColor: return Self.color(attributes[.foregroundColor] as? UIColor ?? label.textColor).propValue
        case .background: return (attributes[.backgroundColor] as? UIColor).map { Self.color($0).propValue }
        case .tracking: return ((attributes[.kern] as? NSNumber)?.doubleValue ?? 0).propValue
        case .textDecorations:
            var decorations: TextDecorations = []
            if (attributes[.underlineStyle] as? Int ?? 0) != 0 { decorations.insert(.underline) }
            if (attributes[.strikethroughStyle] as? Int ?? 0) != 0 { decorations.insert(.strikethrough) }
            return decorations.propValue
        default: throw DriverCannot(reading: property, of: span)
        }
    }
}
