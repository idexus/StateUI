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

    /// The family the words are drawn in; nil for the platform's.
    private(set) var fontFamily: String?

    /// The room around the words the tree describes; nil where the view keeps its own.
    private var padding: Insets?
    private var madePadding: (left: Int32, top: Int32, right: Int32, bottom: Int32)?

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
        applyTypeface()
    }

    /// The family the words are drawn in, as Android names it; one it does not know, or nil, is its own.
    func setFontFamily(_ family: String?) {
        fontFamily = family
        applyTypeface()
    }

    private func applyTypeface() {
        let style = (fontAttributes?.rawValue ?? 0) & 3
        let name = fontFamily.flatMap(Java.string)
        let face = name.flatMap { Java.callStaticObject(JavaAPI.typeface, JavaAPI.createTypeface, .object($0), .int(style)) }
        Java.call(reference, JavaAPI.setTypeface, .object(face), .int(style))
        Java.release(local: face)
        Java.release(local: name)
    }

    /// How the words break, and how many lines show: a line cut or truncated is one line, and only a
    /// truncated one says so.
    func setLines(breaking: LineBreak, maximum: Int?) {
        let single = breaking != .wordWrap && breaking != .characterWrap
        let lines = single ? 1 : maximum.flatMap { $0 > 0 ? Int32($0) : nil } ?? Int32.max
        Java.call(reference, JavaAPI.setMaxLines, .int(lines))
        Java.call(reference, JavaAPI.setHorizontallyScrolling, .bool(breaking == .noWrap))

        let truncation: String? = switch breaking {
        case .headTruncation: "START"
        case .middleTruncation: "MIDDLE"
        case .tailTruncation: "END"
        default: nil
        }
        let at = truncation.map { Java.staticObject(JavaAPI.truncateAt, $0, "Landroid/text/TextUtils$TruncateAt;") }
        withExtendedLifetime(at) { Java.call(reference, JavaAPI.setEllipsize, .object(at?.reference)) }
    }

    /// The words' colour; nil puts back the platform's.
    func setTextColor(_ color: HostValue?) {
        let made = madeWith
        if let argb = color.flatMap(Self.argb) {
            let colors = Java.callStaticObject(
                JavaAPI.views, JavaAPI.textColors, .object(AndroidRenderer.context), .int(argb))
            Java.call(reference, JavaAPI.setTextColors, .object(colors))
            Java.release(local: colors)
        } else {
            Java.call(reference, JavaAPI.setTextColors, .object(made.colors.reference))
        }
    }

    /// The room around the words, in points; nil puts back the platform's.
    func setPadding(_ insets: Insets?) {
        if madePadding == nil {
            madePadding = (
                Java.callInt(reference, JavaAPI.getPaddingLeft), Java.callInt(reference, JavaAPI.getPaddingTop),
                Java.callInt(reference, JavaAPI.getPaddingRight), Java.callInt(reference, JavaAPI.getPaddingBottom))
        }
        padding = insets
        applyPadding()
    }

    /// A new background brings its own padding; the tree's is put back over it.
    /// Design: docs/design/platforms/android/controls.md#the-background-a-view-is-made-with
    override func showBackground(_ drawable: JavaObject?) {
        super.showBackground(drawable)
        if padding != nil { applyPadding() }
    }

    private func applyPadding() {
        guard let made = madePadding else { return }

        let sides = padding.map { (pixels($0.left), pixels($0.top), pixels($0.right), pixels($0.bottom)) } ?? made
        Java.call(reference, JavaAPI.setPadding, .int(sides.0), .int(sides.1), .int(sides.2), .int(sides.3))
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
