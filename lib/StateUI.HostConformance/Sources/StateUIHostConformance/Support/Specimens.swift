// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One view of each kind the library declares, as small as it can be: what a tier's cases dress, so a case written
/// once covers its member on every element wearing the tier.
/// Design: docs/design/host/conformance.md#a-tiers-cases
@_spi(Host) public enum Specimens {
    /// The element a specimen stands for, by its node type's name, dressed; nil for an element with none.
    public static func make(_ element: String, _ dressing: Dressing) -> (any View)? {
        switch element {
        case "ActivityIndicator": return dressing.dress(ActivityIndicator())
        case "Button": return dressing.dress(Button())
        case "Canvas": return dressing.dress(Canvas())
        case "CheckBox": return dressing.dress(CheckBox())
        case "ColorBox": return dressing.dress(ColorBox())
        case "DatePicker": return dressing.dress(DatePicker())
        case "Ellipse": return dressing.dress(Ellipse())
        case "Grid": return dressing.dress(Grid())
        case "HStack": return dressing.dress(HStack())
        case "Image": return dressing.dress(Image())
        case "Label": return dressing.dress(Label())
        case "Line": return dressing.dress(Line())
        case "Map": return dressing.dress(Map())
        case "Path": return dressing.dress(Path())
        case "Picker": return dressing.dress(Picker())
        case "Polygon": return dressing.dress(Polygon())
        case "Polyline": return dressing.dress(Polyline())
        case "ProgressBar": return dressing.dress(ProgressBar())
        case "RadioButton": return dressing.dress(RadioButton())
        case "Rectangle": return dressing.dress(Rectangle())
        case "ScrollView": return dressing.dress(ScrollView())
        case "SearchField": return dressing.dress(SearchField())
        case "Slider": return dressing.dress(Slider())
        case "Stepper": return dressing.dress(Stepper())
        case "Switch": return dressing.dress(Switch())
        case "TextEditor": return dressing.dress(TextEditor())
        case "TextField": return dressing.dress(TextField())
        case "TimePicker": return dressing.dress(TimePicker())
        case "VStack": return dressing.dress(VStack())
        case "WebView": return dressing.dress(WebView())
        case "ZStack": return dressing.dress(ZStack())
        default: return nil
        }
    }

    /// The elements wearing `tier` that have a specimen, in the library's order.
    public static func wearing(_ tier: any Contract.Type) -> [String] {
        var names: [String] = []
        for element in LibraryContracts.elements {
            let name = element.nodeType.name
            guard element.worn.contains(where: { ObjectIdentifier($0) == ObjectIdentifier(tier) }),
                  make(name, Dressing()) != nil
            else { continue }
            names.append(name)
        }
        return names
    }
}
