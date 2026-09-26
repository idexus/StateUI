// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A style sheet with one named style for each kind of view a style can be written for - "Conformance.Button" and
/// the like - each dimming its view to half its opacity, and a page that gives the application that sheet.
enum Styled {
    /// The name of the style for `element`.
    static func key(_ element: String) -> String {
        "Conformance.\(element)"
    }

    /// Every kind's style.
    static var sheet: StyleSheet {
        StyleSheet {
            dimmed(ActivityIndicator.self)
            dimmed(Button.self)
            dimmed(Canvas.self)
            dimmed(CheckBox.self)
            dimmed(ColorBox.self)
            dimmed(DatePicker.self)
            dimmed(Ellipse.self)
            dimmed(Grid.self)
            dimmed(HStack.self)
            dimmed(Image.self)
            dimmed(Label.self)
            dimmed(Line.self)
            dimmed(Map.self)
            dimmed(Path.self)
            dimmed(Picker.self)
            dimmed(Polygon.self)
            dimmed(Polyline.self)
            dimmed(PositionIndicator.self)
            dimmed(ProgressBar.self)
            dimmed(RadioButton.self)
            dimmed(Rectangle.self)
            dimmed(ScrollView.self)
            dimmed(SearchField.self)
            dimmed(Slider.self)
            dimmed(Stepper.self)
            dimmed(Switch.self)
            dimmed(TextEditor.self)
            dimmed(TextField.self)
            dimmed(TimePicker.self)
            dimmed(TitleBar.self)
            dimmed(VStack.self)
            dimmed(WebView.self)
            dimmed(ZStack.self)
        }
    }

    /// The style for `Target`, dimming it to half its opacity.
    private static func dimmed<Target: StyleTarget>(_ target: Target.Type) -> [AnyStyle] {
        StyleBuilder.buildExpression(
            Style<Target>(key(Target().node.type.name)).setValue(VisualElementContract.opacity, 0.5))
    }
}

/// A page whose application wears `Styled.sheet`, holding `inner`.
struct StyledPage: ContentView {
    let inner: any View

    @Environment private var application: ApplicationSession

    var content: any View {
        let (inner, application) = (self.inner, self.application)
        return VStack { inner }.onCreated { application.styles = Styled.sheet }
    }
}
