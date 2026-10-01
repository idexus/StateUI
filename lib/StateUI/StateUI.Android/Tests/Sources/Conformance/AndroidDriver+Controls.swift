// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import CStateUIAndroid
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
@_spi(Host) import StateUIConformance

/// What the Android driver reads of a control's own - a text view's lines, gravity, spacing and hint, a field's
/// selection and kind of input, a view's padding and clipping, a scroller's bars, a picture's scale, a tint - by
/// `TestRead`, in the units Android keeps and back in StateUI's.
/// Design: docs/design/platforms/android/conformance.md#what-the-driver-reads
extension AndroidDriver {
    static func controlHolds(_ property: Prop, _ view: AndroidView) -> HostValue? {
        let reference = view.reference
        let read = { (what: String) in Self.read(reference, what) }
        let number = { (what: String) in read(what).flatMap(Double.init) }
        switch property {
        case .maximumLines: return number("maxLines").map { Int($0).propValue }
        case .lineBreak:
            switch read("ellipsize") {
            case "START": return LineBreak.headTruncation.propValue
            case "MIDDLE": return LineBreak.middleTruncation.propValue
            case "END": return LineBreak.tailTruncation.propValue
            case nil: return nil
            default: return (read("scrollsAcross") == "1" ? LineBreak.noWrap : .wordWrap).propValue
            }
        case .horizontalTextAlignment:
            // Gravity's horizontal bits: centre 1, start or left 3, end or right 5.
            guard let gravity = number("gravity").map(Int.init) else { return nil }
            return (gravity & 7 == 1 ? TextAlignment.center : gravity & 7 == 5 ? .end : .start).propValue
        case .verticalTextAlignment:
            // Gravity's vertical bits: centre 0x10, top 0x30, bottom 0x50.
            guard let gravity = number("gravity").map(Int.init) else { return nil }
            return (gravity & 0x70 == 0x10 ? TextAlignment.center : gravity & 0x70 == 0x50 ? .end : .start).propValue
        case .characterSpacing:
            // Pixels, from ems of the size: back in points, to the tenth.
            return number("letterSpacing").map { ($0 / view.density * 10).rounded() / 10 }?.propValue
        case .lineHeight: return number("lineHeight")?.propValue
        case .textDecorations:
            guard let flags = number("paintFlags").map(Int.init) else { return nil }
            var decorations: TextDecorations = []
            if flags & 8 != 0 { decorations.insert(.underline) }
            if flags & 16 != 0 { decorations.insert(.strikethrough) }
            return decorations.propValue
        case .placeholder where view is AndroidTextFieldView: return read("hint")?.propValue
        case .placeholderColor where view is AndroidTextFieldView:
            return number("hintColor").map { color(UInt32(bitPattern: Int32(truncatingIfNeeded: Int($0)))).propValue }
        case .cursorPosition where view is AndroidTextFieldView: return number("selectionStart").map { Int($0).propValue }
        case .selectionLength where view is AndroidTextFieldView:
            guard let start = number("selectionStart"), let end = number("selectionEnd") else { return nil }
            return Int(end - start).propValue
        case .isPassword where view is AndroidTextFieldView:
            return number("inputType").map { (Int($0) & 0x80 != 0).propValue }
        case .inputPurpose where view is AndroidTextFieldView:
            return number("inputType").map { purpose(of: Int($0)).propValue }
        case .isTextPredictionEnabled where view is AndroidTextFieldView:
            return number("inputType").map { (Int($0) & 0x80000 == 0).propValue }
        case .padding where !(view is AndroidLayoutView):
            // Whole pixels on Android: a fraction of a point off, back to the whole points the tree gives.
            let sides = read("padding")?.split(separator: ",").compactMap { Double($0) } ?? []
            guard sides.count == 4 else { return nil }
            let points = sides.map { ($0 / view.density).rounded() }
            return Insets(points[0], points[1], points[2], points[3]).propValue
        case .clipsContent where view is AndroidLayoutView: return (read("clipToOutline") == "1").propValue
        case .verticalScrollBarVisibility, .horizontalScrollBarVisibility:
            guard let scroller = (view as? AndroidScrollView)?.scrollers.first else { return nil }
            let bar = Self.read(scroller.reference, property == .verticalScrollBarVisibility ? "verticalBar" : "horizontalBar")
            let bars: [String: ScrollBarVisibility] = ["never": .never, "always": .always, "default": .default]
            return bar.flatMap { bars[$0] }?.propValue
        case .aspect where view is AndroidImageView:
            let aspects: [String: Aspect] = ["FIT_CENTER": .fit, "CENTER_CROP": .fill, "FIT_XY": .stretch, "CENTER": .center]
            return read("scaleType").flatMap { aspects[$0] }?.propValue
        case .tint:
            return number("tint").map { color(UInt32(bitPattern: Int32(truncatingIfNeeded: Int($0)))).propValue }
        default: return nil
        }
    }

    /// The purpose an input type was made for: its class, then its variation, then its capitals and suggestions.
    private static func purpose(of type: Int) -> InputPurpose {
        switch (type & 0xF, type & 0xFF0) {
        case (2, _): return .numeric
        case (3, _): return .telephone
        case (_, 0x20): return .email
        case (_, 0x10): return .url
        default:
            if type & 0x4000 != 0 { return .text }
            return type & 0x80000 != 0 ? .plain : .default
        }
    }

    /// What `view` holds of `what`, as `TestRead` writes it; nil where it holds nothing of it.
    static func read(_ view: jobject, _ what: String) -> String? {
        Java.frame {
            Java.callStaticObject(testRead, reading, .object(view), .object(Java.string(what))).map { Java.text($0) }
        }
    }

    static let testRead = Java.findClass("stateui/android/test/TestRead")
    static let reading = Java.staticMethod(
        testRead, "read", "(Landroid/view/View;Ljava/lang/String;)Ljava/lang/String;")
}
