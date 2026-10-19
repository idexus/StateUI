// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// StateUI's values as CSS writes them: lengths in pixels, colours in sRGB, an inset's sides by their logical names -
/// its leading side is the inline start, so a layout right to left turns them by itself.
/// Design: docs/design/platforms/web/layout.md#values-in-css
enum WebCSS {
    /// A number as CSS reads it: whole as it is, any other to a millionth with no nought trailing - spelt by whole
    /// numbers, as a double's shortest spelling costs a browser running WebAssembly with no compiler much.
    /// Design: docs/design/platforms/web/layout.md#values-in-css
    static func number(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        let whole = value.rounded()
        if whole == value, abs(whole) < 1e15 { return String(Int64(whole)) }
        guard abs(value) < 1e12 else { return String(value) }

        var left = UInt64((abs(value) * 1_000_000).rounded())
        guard left != 0 else { return "0" }

        // The digits from the last, into one buffer: the fraction's but its trailing noughts, the point, the units.
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 24) { buffer in
            var at = 24
            func put(_ byte: UInt8) {
                at -= 1
                buffer[at] = byte
            }
            var places = 0
            var written = false
            while places < 6 {
                let digit = UInt8(left % 10)
                left /= 10
                places += 1
                if digit != 0 || written {
                    put(48 + digit)
                    written = true
                }
            }
            if written { put(46) }
            repeat {
                put(48 + UInt8(left % 10))
                left /= 10
            } while left != 0
            if value < 0 { put(45) }
            return String(decoding: UnsafeBufferPointer(rebasing: buffer[at..<24]), as: UTF8.self)
        }
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
    /// A size in points as the browser's text size counts it: a sixteenth of a rem each.
    static func rems(_ value: Double) -> String {
        number(max(0, value) / 16) + "rem"
    }

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
        // A radius past the box's size is cut down by the browser to half its shorter side, whatever its size.
        case .capsule: "9999px"
        case .ellipse: "50%"
        }
    }

    /// A look's font and colour as CSS - what it leaves unsaid none, so the words take it from around them: its
    /// style's size and weight from the Web's type ramp, under the size and weight it gives. A size stands in rems,
    /// which the browser's text size scales, where the words scale, and in pixels where not - the page's own size
    /// held fixed where the look gives none.
    /// Design: docs/design/platforms/web/controls.md#a-text-style
    static func font(_ look: TextLook) -> [(String, String?)] {
        let (size, weight) = look.standing(styleSize: look.style?.webSize, styleWeight: look.style?.webWeight)
        return [("font-size", look.scales ? size.map(rems) : pixels(size) ?? "var(--stateui-words-fixed)"),
                ("font-weight", weight.map { String($0.number) }),
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

    /// The most a child's length may be: `most` where it is stated, and no more than its slot where it is `bound`.
    static func most(_ most: Double?, bound: Bool) -> String? {
        switch (pixels(most), bound) {
        case (let stated?, true): "min(\(stated), 100%)"
        case (let stated?, false): stated
        case (nil, true): "100%"
        case (nil, false): nil
        }
    }

    /// Where a child stands across a slot: its start, its middle, its end, or the whole of it. A filling child its
    /// own size stops short of the slot stands in the middle, as the host layer's arithmetic places it.
    static func alignment(_ option: Int32, stops stated: Bool) -> String {
        switch option {
        case 0: "start"
        case 1: "center"
        case 2: "end"
        default: stated ? "center" : "stretch"
        }
    }
}

extension TextStyle {
    /// The style's size on the Web's type ramp, in CSS pixels at the browser's own text size: the body's is the
    /// page's.
    var webSize: Double {
        switch self {
        case .display: 34
        case .title: 26
        case .subtitle: 20
        case .headline, .body: 15
        case .caption: 12
        }
    }

    /// The style's weight on the Web's type ramp.
    var webWeight: FontWeight {
        switch self {
        case .display, .title, .subtitle, .headline: .semibold
        case .body, .caption: .regular
        }
    }
}
