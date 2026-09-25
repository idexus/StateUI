// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// The host's rules for the whole display, each a class named for what it says, which a widget wears to take it.
/// Design: docs/design/platforms/gtk/drawing.md#a-widgets-own-box
@MainActor
enum GTKStyleSheet {
    private static var provider: UnsafeMutablePointer<GtkCssProvider>?
    private static var rules: [String: String] = [:]

    /// The class giving a widget `insets` of room between its edge and its content.
    static func padding(_ insets: Insets) -> String {
        let sides = [insets.top, insets.right, insets.bottom, insets.left].map { max(0, $0.isFinite ? $0 : 0) }
        let name = "stateui-padding-" + sides.map { css($0).replacing(".", with: "_") }.joined(separator: "-")
        write(name, "padding: " + sides.map { css($0) + "px" }.joined(separator: " ") + ";")
        return name
    }

    /// The class painting a bar in `background`, what stands on it in `foreground`; nil where neither is given.
    static func bar(background: GdkRGBA?, foreground: GdkRGBA?) -> String? {
        guard background != nil || foreground != nil else { return nil }
        var name = "stateui-bar"
        var body = ""
        if let background {
            name += "-b" + hex(background)
            body += "background: \(css(background)); box-shadow: none; "
        }
        if let foreground {
            name += "-f" + hex(foreground)
            body += "color: \(css(foreground)); "
        }
        write(name, body)
        return name
    }

    /// Writes the rule for `name` the first time it is asked for, the whole sheet in the rules' order.
    private static func write(_ name: String, _ body: String) {
        guard rules[name] == nil else { return }
        rules[name] = body

        let provider = self.provider ?? {
            let made = gtk_css_provider_new()!
            gtk_style_context_add_provider_for_display(
                gdk_display_get_default(), made.opaque, guint(GTK_STYLE_PROVIDER_PRIORITY_APPLICATION))
            self.provider = made
            return made
        }()
        let sheet = rules.keys.sorted().map { ".\($0) { \(rules[$0]!) }" }.joined(separator: "\n")
        gtk_css_provider_load_from_string(provider, sheet)
    }

    /// A colour as CSS writes it.
    private static func css(_ color: GdkRGBA) -> String {
        let channels = [color.red, color.green, color.blue].map { String(Int((min(max($0, 0), 1) * 255).rounded())) }
        return "rgba(\(channels.joined(separator: ", ")), \(css(Double(min(max(color.alpha, 0), 1)))))"
    }

    /// A colour's channels in hex, red to alpha.
    private static func hex(_ color: GdkRGBA) -> String {
        [color.red, color.green, color.blue, color.alpha].map { channel in
            let value = Int((min(max(channel, 0), 1) * 255).rounded())
            let digits = String(value, radix: 16, uppercase: true)
            return value < 16 ? "0" + digits : digits
        }.joined()
    }

    /// A number as CSS writes it: whole without a point.
    private static func css(_ number: Double) -> String {
        number == number.rounded() ? String(Int(number)) : String(number)
    }
}
