// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// libadwaita's type ramp: the size and weight GTK's style gives a label wearing each text style's class, read from
/// labels of those classes, never shown - the theme's own numbers, following the desktop's font.
/// Design: docs/design/platforms/gtk/controls.md#a-text-style
@MainActor
enum GTKTypeRamp {
    /// A label of each style's class.
    private static var probes: [TextStyle: GTKWidget] = [:]

    /// The size of `style`, in StateUI's points, and its weight's number on libadwaita's type ramp.
    static func step(_ style: TextStyle) -> (size: Double, weight: Int) {
        let probe = probes[style] ?? {
            let label = gtk_label_new(nil)!
            g_object_ref_sink(label)
            gtk_widget_add_css_class(label, style.adwaitaClass)
            probes[style] = label
            return label
        }()
        guard let font = pango_context_get_font_description(gtk_widget_get_pango_context(probe)) else {
            return (GTKEnvironment.fontSize, FontWeight.regular.number)
        }
        let size = Double(pango_font_description_get_size(font)) / Double(PANGO_SCALE)
        let points = pango_font_description_get_size_is_absolute(font) != 0 ? size : size * 96 / 72
        return (points, Int(pango_font_description_get_weight(font).rawValue))
    }
}

extension TextStyle {
    /// libadwaita's style class for the style.
    var adwaitaClass: String {
        switch self {
        case .display: "title-1"
        case .title: "title-2"
        case .subtitle: "title-4"
        case .headline: "heading"
        case .body: "body"
        case .caption: "caption"
        }
    }
}

extension TextLook {
    /// The size and the weight's number the words stand at on GTK: the tree's, else their style's on libadwaita's
    /// type ramp - its own number, which may stand between StateUI's weights.
    @MainActor
    var gtkStanding: (size: Double?, weight: Int?) {
        let step = style.map(GTKTypeRamp.step)
        let (size, weight) = standing(styleSize: step?.size, styleWeight: step.map { FontWeight(nearest: Double($0.weight)) })
        return (size, self.weight == nil ? step?.weight : weight?.number)
    }
}
