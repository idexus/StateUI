// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// An `android.widget.TextView` or a subclass: the words, their size, weight and colour.
@MainActor
class AndroidTextView: AndroidView {
    private var made: (size: Float, colors: JavaObject)?

    /// Bold and italic, as last set.
    private(set) var fontAttributes: FontAttributes?

    /// The words shown.
    func setText(_ text: String) {
        let string = Java.string(text)
        Java.call(reference, JavaAPI.setText, .object(string))
        Java.release(local: string)
    }

    /// The words the view shows now, read back.
    var text: String {
        guard let sequence = Java.callObject(reference, JavaAPI.getText) else { return "" }

        let string = Java.callObject(sequence, JavaAPI.toString)
        defer {
            Java.release(local: string)
            Java.release(local: sequence)
        }
        return Java.text(string)
    }

    /// The size of the words, in points the user's font scale applies to; nil puts back the platform's.
    func setFontSize(_ size: Double?) {
        let made = madeWith
        if let size {
            Java.call(reference, JavaAPI.setTextSize, .int(ViewConstants.scaledPixels), .float(Float(size)))
        } else {
            Java.call(reference, JavaAPI.setTextSize, .int(ViewConstants.pixels), .float(made.size))
        }
    }

    /// Bold and italic, in the bits `FontAttributes` and `Typeface` share.
    func setFontAttributes(_ attributes: FontAttributes?) {
        fontAttributes = attributes
        Java.call(reference, JavaAPI.setTypeface, .object(nil), .int((attributes?.rawValue ?? 0) & 3))
    }

    /// The words' colour; nil puts back the platform's.
    func setTextColor(_ color: HostValue?) {
        let made = madeWith
        if let argb = color.flatMap(Self.argb) {
            Java.call(reference, JavaAPI.setTextColor, .int(argb))
        } else {
            Java.call(reference, JavaAPI.setTextColors, .object(made.colors.reference))
        }
    }

    /// The size and colours the view was made with, read before the first change.
    private var madeWith: (size: Float, colors: JavaObject) {
        if let kept = made { return kept }

        let kept = (
            size: Java.callFloat(reference, JavaAPI.getTextSize),
            colors: JavaObject(Java.callObject(reference, JavaAPI.getTextColors)!))
        made = kept
        return kept
    }
}
