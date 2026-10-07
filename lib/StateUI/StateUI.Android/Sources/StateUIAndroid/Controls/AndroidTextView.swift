// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A Text: a `TextView` - its words, or runs of them each in its own colour, size and weight.
/// Design: docs/design/platforms/android/controls.md#a-labels-words
@MainActor
final class AndroidTextView: AndroidTextualView {

    /// Where the label's place travels: its words stand at that size meanwhile.
    /// Design: docs/design/host/motion.md#words-at-their-destination
    private var bound: Rect?

    override func travels(to destination: Rect?) {
        bound = destination
    }

    override var wordsRoom: Rect? { bound }

    init() {
        super.init { _ in Java.new(JavaAPI.textView, JavaAPI.newTextView, .object(AndroidRenderer.context)) }
    }

    /// The words as runs, each spanning its own part of them with how its look differs from the label's.
    func setRuns(_ runs: [TextRun]) {
        let point = Self.pointPixels
        Java.frame {
            let words = Java.new(JavaAPI.spannableBuilder, JavaAPI.newSpannableBuilder)
            var start: Int32 = 0
            for run in runs {
                let end = start + Int32(run.text.utf16.count)
                Java.release(local: Java.callObject(words.reference, JavaAPI.append, .object(Java.string(run.text))))
                for span in spans(of: run, point: point) {
                    Java.call(
                        words.reference, JavaAPI.setSpan,
                        .object(span.reference), .int(start), .int(end), .int(Self.exclusive))
                }
                start = end
            }
            withExtendedLifetime(words) { Java.call(reference, JavaAPI.setText, .object(words.reference)) }
        }
        setLetterSpacing(letterSpacing)
    }

    /// The Java spans that make a run differ from the label: its colour, size, family, weight, background and
    /// lines. Android spaces the letters of a whole text alone.
    private func spans(of run: TextRun, point: Double) -> [JavaObject] {
        let look = run.look
        var spans: [JavaObject] = []
        if let argb = look.color.flatMap(Self.argb) {
            spans.append(Java.new(JavaAPI.foregroundSpan, JavaAPI.newForegroundSpan, .int(argb)))
        }
        if let size = look.size {
            let pixels = Int32((size * point).rounded())
            spans.append(Java.new(JavaAPI.sizeSpan, JavaAPI.newSizeSpan, .int(pixels), .bool(false)))
        }
        let style = look.attributes.rawValue & 3
        if let family = look.family, let face = Java.callStaticObject(
            JavaAPI.typeface, JavaAPI.createTypeface, .object(Java.string(family)), .int(style)) {
            spans.append(Java.new(JavaAPI.typefaceSpan, JavaAPI.newTypefaceSpan, .object(face)))
        }
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
        Java.call(
            reference, JavaAPI.setGravity,
            .int(ViewConstants.gravity(across: horizontal) | ViewConstants.gravity(down: vertical)))
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

    /// `Spanned.SPAN_EXCLUSIVE_EXCLUSIVE`, and `Paint`'s underline and strike-through flags.
    private static let exclusive: Int32 = 33
    private static let underline: Int32 = 8
    private static let strikethrough: Int32 = 16

    /// The pixels of one point of text the user's font scale applies to - Android's scaled pixel, the label's
    /// own size's unit - which a run's size is drawn in.
    private static var pointPixels: Double {
        Java.frame {
            let resources = Java.callObject(AndroidRenderer.context, JavaAPI.getResources)!
            let metrics = Java.callObject(resources, JavaAPI.getDisplayMetrics)!
            return Double(Java.callStaticFloat(
                JavaAPI.typedValue, JavaAPI.applyDimension, .int(ViewConstants.scaledPixels), .float(1), .object(metrics)))
        }
    }
}
