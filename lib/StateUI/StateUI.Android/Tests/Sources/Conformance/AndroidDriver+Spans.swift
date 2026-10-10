// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import CStateUIAndroid
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
@_spi(Host) import StateUIConformance

/// What the Android driver reads of a run of a text's words: the part of its text view's words the run stands
/// over (`RunPlace`) and the spans Android holds there.
/// Design: docs/design/platforms/android/conformance.md#what-the-driver-reads
extension AndroidDriver {
    func spanHolds(_ property: Prop, on span: MountedElement) throws -> HostValue? {
        guard let place = RunPlace(of: span), let view = (place.text.native as? AndroidElement)?.view as? AndroidTextView
        else { throw DriverCannot(reading: property, of: span) }
        let (start, end) = (Int32(place.range.lowerBound), Int32(place.range.upperBound))
        let reference = view.reference
        switch property {
        case .text:
            return Java.frame {
                Java.callStaticObject(Self.testSpans, Self.spanWords, .object(reference), .int(start), .int(end))
                    .map { .string(Java.text($0)) }
            }
        case .fontSize:
            return Double(Java.callStaticFloat(Self.testSpans, Self.spanPoints, .object(reference), .int(start)))
                .rounded().propValue
        case .isFontAutoScalingEnabled:
            return try Self.scales(Java.callStaticInt(Self.testSpans, Self.spanScales, .object(reference), .int(start)))
        case .fontAttributes:
            let style = Java.callStaticInt(Self.testSpans, Self.spanStyle, .object(reference), .int(start))
            return FontAttributes(rawValue: style & 3).propValue
        case .textColor:
            let argb = Java.callStaticInt(Self.testSpans, Self.spanColor, .object(reference), .int(start))
            return Self.color(UInt32(bitPattern: argb)).propValue
        case .textDecorations:
            let lines = Java.callStaticInt(Self.testSpans, Self.spanLines, .object(reference), .int(start))
            var decorations: TextDecorations = []
            if lines & 1 != 0 { decorations.insert(.underline) }
            if lines & 2 != 0 { decorations.insert(.strikethrough) }
            return decorations.propValue
        case .background:
            let argb = UInt32(bitPattern: Java.callStaticInt(Self.testSpans, Self.spanBackground, .object(reference), .int(start)))
            return argb == 0 ? nil : Self.color(argb).propValue
        case .fontFamily: throw DriverCannot("read a family", because: "Android's typeface keeps no family's name")
        default: throw DriverCannot(reading: property, of: span)
        }
    }

    static let testSpans = Java.findClass("stateui/android/test/TestSpans")
    static let spanWords = Java.staticMethod(testSpans, "words", "(Landroid/widget/TextView;II)Ljava/lang/String;")
    static let spanPoints = Java.staticMethod(testSpans, "points", "(Landroid/widget/TextView;I)F")
    static let spanColor = Java.staticMethod(testSpans, "color", "(Landroid/widget/TextView;I)I")
    static let spanStyle = Java.staticMethod(testSpans, "style", "(Landroid/widget/TextView;I)I")
    static let spanScales = Java.staticMethod(testSpans, "scales", "(Landroid/widget/TextView;I)I")
    static let spanLines = Java.staticMethod(testSpans, "lines", "(Landroid/widget/TextView;I)I")
    static let spanBackground = Java.staticMethod(testSpans, "background", "(Landroid/widget/TextView;I)I")
}
