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

    /// A length in pixels; nil for none.
    static func pixels(_ value: Double?) -> String? {
        value.map { number(max(0, $0)) + "px" }
    }

    /// An inset's four sides: leading, top, trailing and bottom, as CSS's logical sides.
    static func sides(_ insets: Insets?) -> [(side: String, length: String?)] {
        [("inline-start", insets?.left), ("block-start", insets?.top), ("inline-end", insets?.right),
         ("block-end", insets?.bottom)].map { ($0, $1.flatMap { $0 == 0 ? nil : pixels($0) }) }
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
    static func alignment(_ option: Int32, stops stated: Bool) -> String {
        switch option {
        case 0: "start"
        case 1: "center"
        case 2: "end"
        default: stated ? "center" : "stretch"
        }
    }
}
