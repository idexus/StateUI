// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A Label: a `TextView` - its words, or runs of them each in its own colour, size and weight.
/// Design: docs/design/platforms/android/controls.md#a-labels-words
@MainActor
final class AndroidLabelView: AndroidTextView {
    /// The space between the letters, in points.
    private var spacing = 0.0

    init() {
        super.init { _ in Java.new(JavaAPI.textView, JavaAPI.newTextView, .object(AndroidRenderer.context)) }
    }

    /// The words as runs, each spanning its own part of them with how its look differs from the label's.
    func setRuns(_ runs: [TextRun]) {
        let scale = Self.fontScale
        Java.frame {
            let words = Java.new(JavaAPI.spannableBuilder, JavaAPI.newSpannableBuilder)
            var start: Int32 = 0
            for run in runs {
                let end = start + Int32(run.text.utf16.count)
                Java.release(local: Java.callObject(words.reference, JavaAPI.append, .object(Java.string(run.text))))
                for span in spans(of: run, scale: scale) {
                    Java.call(
                        words.reference, JavaAPI.setSpan,
                        .object(span.reference), .int(start), .int(end), .int(Self.exclusive))
                }
                start = end
            }
            withExtendedLifetime(words) { Java.call(reference, JavaAPI.setText, .object(words.reference)) }
        }
        setLetterSpacing(spacing)
    }

    /// The Java spans that make a run differ from the label.
    private func spans(of run: TextRun, scale: Double) -> [JavaObject] {
        let look = run.look
        var spans: [JavaObject] = []
        if let argb = look.color.flatMap(Self.argb) {
            spans.append(Java.new(JavaAPI.foregroundSpan, JavaAPI.newForegroundSpan, .int(argb)))
        }
        if let size = look.size {
            let pixels = Int32((size * density * scale).rounded())
            spans.append(Java.new(JavaAPI.sizeSpan, JavaAPI.newSizeSpan, .int(pixels), .bool(false)))
        }
        let style = look.attributes.rawValue & 3
        if style != 0 {
            spans.append(Java.new(JavaAPI.styleSpan, JavaAPI.newStyleSpan, .int(style)))
        }
        if let argb = look.background.flatMap(Self.argb) {
            spans.append(Java.new(JavaAPI.backgroundSpan, JavaAPI.newBackgroundSpan, .int(argb)))
        }
        if look.decorations.contains(.underline) {
            spans.append(Java.new(JavaAPI.underlineSpan, JavaAPI.newUnderlineSpan))
        }
        if look.decorations.contains(.strikethrough) {
            spans.append(Java.new(JavaAPI.strikethroughSpan, JavaAPI.newStrikethroughSpan))
        }
        return spans
    }

    /// Where the words stand in the label's room, across and down.
    func setAlignment(horizontal: TextAlignment, vertical: TextAlignment) {
        let across: Int32 = switch horizontal {
        case .start: 0x0080_0003
        case .center: 0x01
        case .end: 0x0080_0005
        }
        let down: Int32 = switch vertical {
        case .start: 0x30
        case .center: 0x10
        case .end: 0x50
        }
        Java.call(reference, JavaAPI.setGravity, .int(across | down))
    }

    /// The space between the letters in points, which Android counts in the text's own size.
    func setLetterSpacing(_ points: Double) {
        spacing = points
        let size = Double(Java.callFloat(reference, JavaAPI.getTextSize))
        Java.call(reference, JavaAPI.setLetterSpacing, .float(size > 0 ? Float(points * density / size) : 0))
    }

    /// The height of a line, as a multiple of the font's own; nil for the font's.
    func setLineHeight(_ multiple: Double?) {
        Java.call(reference, JavaAPI.setLineSpacing, .float(0), .float(Float(multiple.flatMap { $0 > 0 ? $0 : nil } ?? 1)))
    }

    /// A line under the words, or through them.
    func setDecorations(_ decorations: TextDecorations?) {
        var flags = Java.callInt(reference, JavaAPI.getPaintFlags) & ~(Self.underline | Self.strikethrough)
        if decorations?.contains(.underline) == true { flags |= Self.underline }
        if decorations?.contains(.strikethrough) == true { flags |= Self.strikethrough }
        Java.call(reference, JavaAPI.setPaintFlags, .int(flags))
    }

    override func setFontSize(_ size: Double?) {
        super.setFontSize(size)
        setLetterSpacing(spacing)
    }

    /// `Spanned.SPAN_EXCLUSIVE_EXCLUSIVE`, and `Paint`'s underline and strike-through flags.
    private static let exclusive: Int32 = 33
    private static let underline: Int32 = 8
    private static let strikethrough: Int32 = 16

    /// The user's scale for text, which a run's size in points is drawn at, as the label's is.
    private static var fontScale: Double {
        Java.frame {
            let resources = Java.callObject(AndroidRenderer.context, JavaAPI.getResources)!
            let configuration = Java.callObject(resources, JavaAPI.getConfiguration)!
            return Double(Java.float(configuration, JavaAPI.fontScale))
        }
    }
}
