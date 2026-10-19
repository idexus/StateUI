// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// The host's rules for the whole display, each a class named for what it says, which a widget wears to take it.
/// Design: docs/design/platforms/gtk/drawing.md#a-widgets-own-box
@MainActor
enum GTKStyleSheet {
    private static var provider: UnsafeMutablePointer<GtkCssProvider>?
    private static var rules: [String: String] = [:]

    /// How many rules the sheet holds - what a test counts.
    static var ruleCount: Int { rules.count }

    /// The class giving a widget `insets` of room between its edge and its content.
    static func padding(_ insets: Insets) -> String {
        let sides = [insets.top, insets.right, insets.bottom, insets.left].map { max(0, $0.isFinite ? $0 : 0) }
        let name = "stateui-padding-" + sides.map { css($0).replacing(".", with: "_") }.joined(separator: "-")
        let room = sides.map { css($0) + "px" }.joined(separator: " ")
        // A menu button's and a split button's room is their buttons', which hold the words: a split button's arrow
        // keeps the theme's room across.
        let held = "menubutton.\(name), splitbutton.\(name) { padding: 0; }\n"
            + "menubutton.\(name) > button, splitbutton.\(name) > button { padding: \(room); }\n"
            + "splitbutton.\(name) > menubutton > button { padding-top: \(css(sides[0]))px; "
            + "padding-bottom: \(css(sides[2]))px; }\n"
        write(name, "padding: \(room);", states: held)
        return name
    }

    /// The class writing a flat button's words in the theme's colour for destroying something.
    static var destructiveWords: String {
        write("stateui-destructive", "color: @destructive_color;")
        return "stateui-destructive"
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

    /// The class drawing a button's box: its fill - a little fainter under the pointer and fainter again pressed,
    /// which the theme's own states would otherwise lose under it - its outline and its shape; nil where nothing is
    /// given.
    static func box(fill: GdkRGBA?, stroke: GdkRGBA?, lineWidth: Double?, shape: ContainerShape?) -> String? {
        guard fill != nil || stroke != nil || shape != nil else { return nil }
        var name = "stateui-box"
        var face = ""
        var corners: String?
        if let fill {
            name += "-f" + hex(fill)
            face += "background: \(css(fill)); box-shadow: none; "
        }
        if let stroke, let lineWidth {
            name += "-s" + hex(stroke) + "-w" + css(lineWidth).replacing(".", with: "_")
            face += "border: \(css(lineWidth))px solid \(css(stroke)); "
        }
        if let shape {
            let part: String
            (part, corners) = switch shape {
            case .rectangle: ("0", "0")
            case .roundedRectangle(let radius): (css(radius).replacing(".", with: "_"), css(radius) + "px")
            // GTK cuts corners wider than the box down alike, to half its shorter side: a capsule at any size.
            case .capsule: ("capsule", "9999px")
            // A share of the box's own sides, across and down: an oval.
            case .ellipse: ("oval", "50%")
            }
            name += "-r" + part
        }
        var states = ""
        // A menu button draws its box with the button it holds, GTK's documented node: the look goes there. A split
        // button wears it whole, its two buttons answering the pointer over it, the line between them drawn.
        // Design: docs/design/platforms/gtk/controls.md#a-buttons-box
        let menu = "menubutton.\(name)", split = "splitbutton.\(name)"
        let halves = ["\(split) > button", "\(split) > menubutton > button"]
        states += [menu, menu + ":hover", menu + ":active"].joined(separator: ", ")
            + " { background: none; border: none; box-shadow: none; }\n"
        states += "\(menu) > button { \(face)\(corners.map { "border-radius: \($0); " } ?? "")}\n"
        states += halves.joined(separator: ", ") + " { background: none; border: none; }\n"
        states += halves.map { $0 + ":hover" }.joined(separator: ", ") + " { background: alpha(currentColor, 0.1); }\n"
        states += halves.map { $0 + ":active" }.joined(separator: ", ") + " { background: alpha(currentColor, 0.2); }\n"
        states += "\(split) > separator { background: alpha(currentColor, 0.35); }\n"
        if let corners {
            let start = "\(corners) 0 0 \(corners)", end = "0 \(corners) \(corners) 0"
            states += "\(halves[0]):dir(ltr), \(halves[1]):dir(rtl) { border-radius: \(start); }\n"
            states += "\(halves[0]):dir(rtl), \(halves[1]):dir(ltr) { border-radius: \(end); }\n"
        }
        if var fill {
            let alpha = fill.alpha
            states += "\(split):hover, \(split):active { background: \(css(fill)); }\n"
            fill.alpha = alpha * Float(PressedFill.underPointer)
            states += ".\(name):hover, \(menu) > button:hover { background: \(css(fill)); }\n"
            fill.alpha = alpha * Float(PressedFill.pressed)
            states += ".\(name):active, \(menu) > button:active { background: \(css(fill)); }\n"
        }
        write(name, face + (corners.map { "border-radius: \($0); " } ?? ""), states: states)
        return name
    }

    /// The class filling a widget's box in `color`.
    static func fill(_ color: GdkRGBA) -> String {
        let name = "stateui-fill-" + hex(color)
        write(name, "background: \(css(color));")
        return name
    }

    /// The class giving a control its tint: the colour its `accent` - a node or a state of it, as a selector after
    /// the control's own - is filled in; its own words and marks where `accent` is nil.
    static func tint(_ color: GdkRGBA, on accent: String?) -> String {
        guard let accent else {
            let name = "stateui-tint-" + hex(color)
            write(name, "color: \(css(color));")
            return name
        }
        let name = "stateui-tint-" + hex(color) + "-" + String(accent.filter(\.isLetter))
        write(name, "", states: ".\(name)\(accent) { background-color: \(css(color)); }\n")
        return name
    }

    /// The class of a split view whose sidebar stands beside the page: the sidebar's pane lets the window through -
    /// shaded a breath as GNOME shades where `shaded`, the platform's own; clear under a material of the tree's.
    static func sidebarBeside(shaded: Bool) -> String {
        let name = shaded ? "stateui-sidebar-shaded" : "stateui-sidebar-clear"
        let ground = shaded ? "alpha(@shade_color, 0.6)" : "transparent"
        write(name, "", states: ".\(name) > .sidebar-pane { background-color: \(ground); }\n")
        return name
    }

    /// The class drawing an editor's box as an entry's: faintly filled in its words' colour, its corners rounded,
    /// ringed in the accent while it holds the focus, the text view on it clear.
    static var editor: String {
        let name = "stateui-editor"
        write(name, "background-color: alpha(currentColor, 0.1); border-radius: 6px; outline: 0 solid transparent;",
              states: ".\(name):focus-within { outline: 2px solid alpha(@accent_color, 0.5); outline-offset: -2px; }\n"
                + ".\(name) > textview, .\(name) > textview > text { background-color: transparent; }\n")
        return name
    }

    /// The class of a list or a grid: what stands under it shows behind its rows, and an item chosen is shaded in
    /// the colour of its words, as GNOME's sidebars shade theirs - no hue of the theme's own over the page. A row and
    /// a grid's child keep no padding of the theme's: an item stands where StateUI's spacing puts it.
    static var collection: String {
        let name = "stateui-collection"
        let chosen = [".\(name) > row:selected", ".\(name) > child:selected"]
        write(name, "background: none;",
              states: ".\(name) > row, .\(name) > child { padding: 0; margin: 0; min-height: 0; min-width: 0; }\n"
                + chosen.joined(separator: ", ") + " { background-color: alpha(currentColor, 0.1); }\n"
                + chosen.map { $0 + ":hover" }.joined(separator: ", ")
                + " { background-color: alpha(currentColor, 0.13); }\n")
        return name
    }

    /// The class giving typed words their look - the font's size, weight, slant and family and the words' colour -
    /// and the placeholder its colour, in a field's own text or as an editor's label, or in its `part` - a selector
    /// after the widget's own; nil where nothing is given.
    static func words(_ look: TextLook, placeholder: GdkRGBA?, in part: String = "") -> String? {
        var name = "stateui-words"
        var body = ""
        let (size, weight) = look.gtkStanding
        // In typographic points where the words scale, which the desktop's text scale applies to; in pixels where not.
        if let size = size ?? (look.scales ? nil : GTKEnvironment.fontSize), size > 0 {
            name += "-s" + css(size).replacing(".", with: "_") + (look.scales ? "" : "x")
            body += look.scales ? "font-size: \(css(TextLook.typographic(size)))pt; " : "font-size: \(css(size))px; "
        }
        if let weight {
            name += "-w\(weight)"
            body += "font-weight: \(weight); "
        }
        if look.attributes.contains(.italic) || look.attributesGiven {
            name += look.attributes.contains(.italic) ? "-i" : "-u"
            body += look.attributes.contains(.italic) ? "font-style: italic; " : "font-style: normal; "
        }
        if let family = look.family, !family.isEmpty {
            name += "-f" + family.utf8.map { String($0, radix: 16) }.joined()
            body += "font-family: \"\(family.replacing("\\", with: "\\\\").replacing("\"", with: "\\\""))\"; "
        }
        if let color = look.rgbaColor {
            name += "-c" + hex(color)
            body += "color: \(css(color)); "
        }
        var states = ""
        if let placeholder {
            name += "-p" + hex(placeholder)
            states = ".\(name) placeholder, .\(name) .\(GTKTextEditorView.placeholderClass) "
                + "{ color: \(css(placeholder)); opacity: 1; }\n"
        }
        guard name != "stateui-words" else { return nil }
        guard !part.isEmpty else {
            write(name, body, states: states)
            return name
        }
        name += "-" + String(part.filter(\.isLetter))
        write(name, "", states: ".\(name)\(part) { \(body)}\n" + states)
        return name
    }

    /// Writes the rule for `name` the first time it is asked for, with the rules for its states, the whole sheet in
    /// the rules' order.
    private static func write(_ name: String, _ body: String, states: String = "") {
        guard rules[name] == nil else { return }
        rules[name] = ".\(name) { \(body) }\n" + states

        let provider = self.provider ?? {
            let made = gtk_css_provider_new()!
            gtk_style_context_add_provider_for_display(
                gdk_display_get_default(), made.opaque, guint(GTK_STYLE_PROVIDER_PRIORITY_APPLICATION))
            self.provider = made
            return made
        }()
        let sheet = rules.keys.sorted().map { rules[$0]! }.joined()
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
