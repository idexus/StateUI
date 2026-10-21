// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// An `android.widget.TextView` or a subclass: the words, their size, weight and color.
@MainActor
class AndroidTextualView: AndroidView {
    private var made: (size: Float, colors: JavaObject)?

    /// The slant, as last set.
    private(set) var fontAttributes: FontAttributes?

    /// The weight, as last set; nil for the platform's.
    private(set) var fontWeight: FontWeight?

    /// The family the words are drawn in; nil for the platform's.
    private(set) var fontFamily: String?

    /// Whether the words' size follows the user's font scale.
    private(set) var scales = true

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

    /// How the words look (`TextMembers.look`): their style's size and weight on the platform's type scale, under
    /// the size and weight they give, their slant, family and color, each the platform's own where the look says
    /// nothing.
    func setLook(_ look: TextLook) {
        scales = look.scales
        let (size, weight) = look.standing(styleSize: look.style?.androidSize, styleWeight: look.style?.androidWeight)
        setFontSize(size)
        fontWeight = weight
        fontAttributes = look.attributes
        fontFamily = look.family
        applyTypeface()
        setTextColor(look.color)
    }

    /// The size of the words in points - Android's scaled pixels where they follow the user's font scale, its
    /// density-independent ones where not; nil puts back the platform's, said in the same unit. The space between
    /// the letters is worked out again for it.
    func setFontSize(_ size: Double?) {
        // The platform's own size is read before the first size written over it.
        let made = madeWith
        let points = size ?? Double(made.size) / Self.pixels(perPoint: true)
        let unit = scales ? ViewConstants.scaledPixels : ViewConstants.independentPixels
        Java.call(reference, JavaAPI.setTextSize, .int(unit), .float(Float(points)))
        setLetterSpacing(letterSpacing)
    }

    /// The pixels of one point of text: Android's scaled pixel where the user's font scale applies to it, its
    /// density-independent pixel where not.
    static func pixels(perPoint scaled: Bool) -> Double {
        Java.frame {
            let resources = Java.callObject(AndroidRenderer.context, JavaAPI.getResources)!
            let metrics = Java.callObject(resources, JavaAPI.getDisplayMetrics)!
            let unit = scaled ? ViewConstants.scaledPixels : ViewConstants.independentPixels
            return Double(Java.callStaticFloat(JavaAPI.typedValue, JavaAPI.applyDimension, .int(unit), .float(1), .object(metrics)))
        }
    }

    /// The space between the letters, in points.
    private(set) var letterSpacing = 0.0

    /// The space between the letters in points, which Android counts in ems of the text's own size.
    func setLetterSpacing(_ points: Double) {
        letterSpacing = points
        var look = TextLook()
        look.letterSpacing = points
        let size = Double(Java.callFloat(reference, JavaAPI.getTextSize)) / density
        Java.call(reference, JavaAPI.setLetterSpacing, .float(Float(look.letterSpacing(inEmsOf: size))))
    }

    /// Draws the words in the family, weight and slant last set again - after anything that put back the
    /// platform's typeface.
    func applyTypeface() {
        let italic = fontAttributes?.contains(.italic) == true
        let face = AndroidTypeface.local(family: fontFamily, weight: fontWeight, italic: italic)
        // A weighted face carries its slant; the platform's takes it from the style bits.
        let style = fontWeight == nil && italic ? AndroidTypeface.italicStyle : 0
        Java.call(reference, JavaAPI.setTypeface, .object(face), .int(style))
        Java.release(local: face)
    }

    /// How the words break, and how many lines show: a line cut or truncated is one line, and only a
    /// truncated one says so; wrapped words held to some lines end the last with an ellipsis.
    func setLines(breaking: LineBreak, maximum: Int?) {
        let lines = breaking.lines(maximum: maximum).map { Int32(clamping: $0) } ?? Int32.max
        Java.call(reference, JavaAPI.setMaxLines, .int(lines))
        Java.call(reference, JavaAPI.setHorizontallyScrolling, .bool(breaking == .noWrap))

        let truncation: String? = switch breaking {
        case .headTruncation: "START"
        case .middleTruncation: "MIDDLE"
        case .tailTruncation: "END"
        default: breaking.endsWithEllipsis(maximum: maximum) ? "END" : nil
        }
        let at = truncation.map { Java.staticObject(JavaAPI.truncateAt, $0, "Landroid/text/TextUtils$TruncateAt;") }
        withExtendedLifetime(at) { Java.call(reference, JavaAPI.setEllipsize, .object(at?.reference)) }
    }

    /// The words' color; nil puts back the platform's (`plainWordColors`).
    func setTextColor(_ color: HostValue?) {
        writtenTextColor = color
        if let argb = color.flatMap(Self.argb) {
            let colors = Java.callStaticObject(
                JavaAPI.views, JavaAPI.textColors, .object(AndroidRenderer.context), .int(argb))
            Java.call(reference, JavaAPI.setTextColors, .object(colors))
            Java.release(local: colors)
        } else {
            let plain = plainWordColors
            withExtendedLifetime(plain) { Java.call(reference, JavaAPI.setTextColors, .object(plain.reference)) }
        }
    }

    /// The color the tree wrote for the words; nil for none.
    private(set) var writtenTextColor: HostValue?

    /// The words' colors where none is written: the platform's, as the view was made.
    var plainWordColors: JavaObject { madeWith.colors }

    /// The direction the view lays out in, which says which side its padding's start stands at.
    var direction = LayoutDirection.leftToRight {
        didSet { if direction != oldValue, padding != nil { applyPadding() } }
    }

    /// The room around the words, in points; nil puts back the platform's.
    func setPadding(_ insets: Insets?) {
        padding = insets
        applyPadding()
    }

    /// The pixels kept on the right beyond the padding: a button's room for its menu's arrow.
    var rightRoom: Int32 = 0 {
        didSet { if rightRoom != oldValue { applyPadding() } }
    }

    /// The padding's right side in pixels, without the room kept beyond it: the tree's, else the platform's.
    var paddingRight: Int32 {
        padding.map { pixels($0.sides(in: direction).right) } ?? platformPadding.right
    }

    /// A new background brings its own padding; the tree's is put back over it.
    /// Design: docs/design/platforms/android/controls.md#the-background-a-view-is-made-with
    override func showBackground(_ drawable: JavaObject?) {
        super.showBackground(drawable)
        if padding != nil || rightRoom != 0 { applyPadding() }
    }

    private func applyPadding() {
        let platform = platformPadding
        let sides = padding.map { $0.sides(in: direction) }
            .map { (pixels($0.left), pixels($0.top), pixels($0.right), pixels($0.bottom)) } ?? platform
        Java.call(reference, JavaAPI.setPadding, .int(sides.0), .int(sides.1), .int(sides.2 + rightRoom), .int(sides.3))
    }

    /// The padding the view was made with, the platform's, read before the first change.
    private var platformPadding: (left: Int32, top: Int32, right: Int32, bottom: Int32) {
        if let madePadding { return madePadding }
        let read = (
            Java.callInt(reference, JavaAPI.getPaddingLeft), Java.callInt(reference, JavaAPI.getPaddingTop),
            Java.callInt(reference, JavaAPI.getPaddingRight), Java.callInt(reference, JavaAPI.getPaddingBottom))
        madePadding = read
        return read
    }

    /// The size and colors the view was made with, read before the first change.
    private var madeWith: (size: Float, colors: JavaObject) {
        if let kept = made { return kept }

        let kept = (
            size: Java.callFloat(reference, JavaAPI.getTextSize),
            colors: JavaObject(Java.callObject(reference, JavaAPI.getTextColors)!))
        made = kept
        return kept
    }
}
