// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// StateUI's values as CSS writes them: lengths in pixels, colours in sRGB, an inset's sides by their logical names -
/// its leading side is the inline start, so a layout right to left turns them by itself.
/// Design: docs/design/platforms/web/layout.md#values-in-css
enum WebCSS {
    /// A number as CSS reads it, with no fraction where it has none.
    static func number(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        let whole = value.rounded()
        return whole == value && abs(whole) < 1e15 ? String(Int64(whole)) : String(value)
    }

    /// A number written with `decimals` places after the point, as a stepper shows it.
    static func number(_ value: Double, decimals: Int) -> String {
        guard value.isFinite else { return "0" }
        let places = max(0, min(decimals, 6))
        var scale = 1.0
        for _ in 0..<places { scale *= 10 }
        let scaled = Int64((abs(value) * scale).rounded())
        let whole = scaled / Int64(scale)
        let sign = value < 0 && scaled != 0 ? "-" : ""
        guard places > 0 else { return sign + String(whole) }
        let fraction = String(scaled % Int64(scale))
        return sign + String(whole) + "." + String(repeating: "0", count: places - fraction.count) + fraction
    }

    /// A length in pixels; nil for none.
    static func pixels(_ value: Double?) -> String? {
        value.map { number(max(0, $0)) + "px" }
    }

    /// A length in pixels that may be below nothing - a place left of or above its room.
    static func signedPixels(_ value: Double) -> String {
        number(value) + "px"
    }

    /// A grid's `count` tracks: those defined, then a share each.
    static func tracks(_ defined: [GridLength], count: Int) -> String? {
        guard count > 0 else { return nil }
        return (0..<count).map { $0 < defined.count ? track(defined[$0]) : "minmax(0, 1fr)" }.joined(separator: " ")
    }

    /// One track: as large as its largest child, a length, or a share of the room the others leave - a share of
    /// nothing still a sliver.
    private static func track(_ length: GridLength) -> String {
        switch length {
        case .auto: "auto"
        case .fixed(let length): pixels(length)!
        case .proportional(let share): "minmax(0, \(number(max(share, 0.0001)))fr)"
        }
    }

    /// An inset's four sides: leading, top, trailing and bottom, as CSS's logical sides - a margin's below nothing
    /// where `signed`, as it shifts a view, a padding's never.
    static func sides(_ insets: Insets?, signed: Bool = false) -> [(side: String, length: String?)] {
        [("inline-start", insets?.left), ("block-start", insets?.top), ("inline-end", insets?.right),
         ("block-end", insets?.bottom)].map {
            ($0, $1.flatMap { $0 == 0 ? nil : signed ? signedPixels($0) : pixels($0) })
        }
    }

    /// Words as a CSS string.
    static func string(_ text: String) -> String {
        "\"" + text.flatMap { $0 == "\"" || $0 == "\\" ? ["\\", $0] : [$0] } + "\""
    }

    /// The corners a box's outline rounds.
    static func corners(_ outline: ContainerShape) -> String? {
        switch outline {
        case .rectangle: nil
        case .roundedRectangle(let radius): pixels(radius)
        case .ellipse: "50%"
        }
    }

    /// A look's font and colour as CSS - what it leaves unsaid none, so the words take it from around them.
    static func font(_ look: TextLook) -> [(String, String?)] {
        [("font-size", pixels(look.size)),
         ("font-weight", look.attributesGiven ? (look.attributes.contains(.bold) ? "700" : "400") : nil),
         ("font-style", look.attributesGiven ? (look.attributes.contains(.italic) ? "italic" : "normal") : nil),
         ("font-family", look.family.map(string)),
         ("color", color(look.color))]
    }

    /// How words break across lines and where they stop - at most `lines` of them, nil for any - as CSS says it.
    static func lines(_ lineBreak: LineBreak, most lines: Int?) -> [(String, String?)] {
        let clamped = lineBreak.wraps && lines != nil
        return [
            ("white-space", lineBreak.wraps ? "pre-wrap" : "pre"),
            ("overflow-wrap", lineBreak.wraps ? "break-word" : nil),
            ("word-break", lineBreak == .characterWrap ? "break-all" : nil),
            ("text-overflow", lineBreak.truncates ? "ellipsis" : nil),
            ("overflow", lineBreak.wraps && !clamped ? nil : "hidden"),
            ("display", clamped ? "-webkit-box" : nil),
            ("-webkit-box-orient", clamped ? "vertical" : nil),
            ("-webkit-line-clamp", clamped ? String(lines!) : nil),
        ]
    }

    /// The room between letters, in points, as CSS's `letter-spacing`; nil for none.
    static func letterSpacing(_ points: Double) -> String? {
        points == 0 ? nil : signedPixels(points)
    }

    /// The rest of a look: the space between the letters, the lines' height and the lines under or through.
    static func spacing(_ look: TextLook) -> [(String, String?)] {
        let lines = [(TextDecorations.underline, "underline"), (.strikethrough, "line-through")]
            .filter { look.decorations.contains($0.0) }.map(\.1)
        return [("letter-spacing", letterSpacing(look.letterSpacing)),
                ("line-height", look.lineHeight.map(number)),
                ("text-decoration-line", lines.isEmpty ? nil : lines.joined(separator: " "))]
    }

    /// A colour as CSS's `rgb()`; nil for a value that is none.
    static func color(_ value: HostValue?) -> String? {
        guard let channels = value?.color else { return nil }
        let alpha = number((Double(channels.alpha) / 255 * 1000).rounded() / 1000)
        return "rgb(\(channels.red) \(channels.green) \(channels.blue) / \(alpha))"
    }

    /// What fills a box: a colour, or a brush's first colour.
    static func fill(_ value: HostValue?) -> String? {
        switch HostBrush(value) {
        case .none: nil
        case .solid(let color): self.color(color)
        default: color(HostBrush(value).firstColor)
        }
    }

    /// Where a child stands across a slot: its start, its middle, its end, or the whole of it. A filling child its
    /// own size stops short of the slot stands in the middle, as the host layer's arithmetic places it.
    /// The most a child's length may be: `most` where it is stated, and no more than its slot where it is `bound`.
    static func most(_ most: Double?, bound: Bool) -> String? {
        switch (pixels(most), bound) {
        case (let stated?, true): "min(\(stated), 100%)"
        case (let stated?, false): stated
        case (nil, true): "100%"
        case (nil, false): nil
        }
    }

    static func alignment(_ option: Int32, stops stated: Bool) -> String {
        switch option {
        case 0: "start"
        case 1: "center"
        case 2: "end"
        default: stated ? "center" : "stretch"
        }
    }
}
