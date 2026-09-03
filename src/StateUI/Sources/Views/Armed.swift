// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The properties that can be FLOWN: the same modifiers, taking the state
// instead of the value.

// Every one of these is the value form with a `Binding` in place of the value,
// and every one is one line over `setValue(_:_:armedOn:)`. Two things about
// where they live, both deliberate:
//
// They are on the ELEMENT-side protocols - `VisualElement`, `View`,
// `StackBase`, `Shape` - and not on the `…Properties` ones the value forms sit
// on, because a `StyleBag` wears every `…Properties` protocol there is: a
// binding written where the value form sits would appear inside `Style<Label>`,
// where it would compile and mean nothing.
//
// The mixins have no element-side twin, so they are constrained
// `where Self: VisualElement` instead - which also keeps them off `TextSpan`,
// a `BindableObject` that MAUI cannot animate at all.
//
// EVERY ONE OF THESE HAS A TWIN IN Views/Driven.swift taking state the host moves in place
// of the `Binding`, and the two differ in where the moving value LIVES: a
// binding's value is `@State`, so every frame of a walk the author asked for
// is reported into the tree, while a number's is on the image and no render
// happens at all. What a value MOVED BY HAND wants is the number form.

// MARK: - VisualElement

extension VisualElement {
    /// How opaque the view is, from 0 to 1, and the state that moves it.
    /// MAUI: VisualElement.Opacity.
    ///
    ///     @State private var fade = 1.0
    ///     …
    ///     Border { … }.opacity($fade)
    ///     …
    ///     try await $fade.animateTo(0.1, length: 400, easing: .cubicOut)
    ///
    /// Assigning `fade` snaps the view to it; flying it walks there. Both go
    /// through this one modifier - the property is ARMED by being written from
    /// a binding at all.
    public func opacity(_ binding: Binding<Double>) -> Modified {
        setValue(.opacity, .number(binding.wrappedValue), armedOn: binding)
    }

    /// What is drawn behind the view, and the state that moves it.
    /// MAUI: VisualElement.BackgroundColor.
    ///
    /// A `Color(light:dark:)` is resolved as it is written, here as anywhere,
    /// so a flight walks to the half the theme is showing.
    public func backgroundColor(_ binding: Binding<Color>) -> Modified {
        setValue(.backgroundColor, binding.wrappedValue.propValue, armedOn: binding)
    }

    /// The width asked for, and the state that moves it.
    /// MAUI: VisualElement.WidthRequest.
    ///
    /// Not `.width($:)`, which is the opposite direction - that one REPORTS
    /// the width a layout settled on and never asks for one.
    public func widthRequest(_ binding: Binding<Double>) -> Modified {
        setValue(.widthRequest, .number(binding.wrappedValue), armedOn: binding)
    }

    /// The height asked for, and the state that moves it.
    /// MAUI: VisualElement.HeightRequest. See `widthRequest` for the trap it
    /// shares with `.height($:)`.
    public func heightRequest(_ binding: Binding<Double>) -> Modified {
        setValue(.heightRequest, .number(binding.wrappedValue), armedOn: binding)
    }

    /// The narrowest the view may be made, and the state that moves it.
    /// MAUI: VisualElement.MinimumWidthRequest.
    public func minimumWidthRequest(_ binding: Binding<Double>) -> Modified {
        setValue(.minimumWidthRequest, .number(binding.wrappedValue), armedOn: binding)
    }

    /// The shortest the view may be made, and the state that moves it.
    /// MAUI: VisualElement.MinimumHeightRequest.
    public func minimumHeightRequest(_ binding: Binding<Double>) -> Modified {
        setValue(.minimumHeightRequest, .number(binding.wrappedValue), armedOn: binding)
    }

    /// The widest the view may be made, and the state that moves it.
    /// MAUI: VisualElement.MaximumWidthRequest.
    public func maximumWidthRequest(_ binding: Binding<Double>) -> Modified {
        setValue(.maximumWidthRequest, .number(binding.wrappedValue), armedOn: binding)
    }

    /// The tallest the view may be made, and the state that moves it.
    /// MAUI: VisualElement.MaximumHeightRequest.
    public func maximumHeightRequest(_ binding: Binding<Double>) -> Modified {
        setValue(.maximumHeightRequest, .number(binding.wrappedValue), armedOn: binding)
    }

    /// How far the view is turned, in degrees, and the state that moves it.
    /// MAUI: VisualElement.Rotation.
    ///
    /// A full turn is arithmetic the author does - `$angle.animateTo(angle +
    /// 360)` - because a flight walks to a value, not by one.
    public func rotation(_ binding: Binding<Double>) -> Modified {
        setValue(.rotation, .number(binding.wrappedValue), armedOn: binding)
    }

    /// How far the view is tipped about its horizontal axis, and the state that
    /// moves it. MAUI: VisualElement.RotationX.
    public func rotationX(_ binding: Binding<Double>) -> Modified {
        setValue(.rotationX, .number(binding.wrappedValue), armedOn: binding)
    }

    /// How far the view is turned about its vertical axis, and the state that
    /// moves it. MAUI: VisualElement.RotationY.
    public func rotationY(_ binding: Binding<Double>) -> Modified {
        setValue(.rotationY, .number(binding.wrappedValue), armedOn: binding)
    }

    /// How much bigger or smaller the view is drawn, and the state that moves
    /// it. MAUI: VisualElement.Scale.
    ///
    /// Drawing only, as the value form is: the room the layout gave the view
    /// does not change while it grows, so nothing around it moves.
    public func scale(_ binding: Binding<Double>) -> Modified {
        setValue(.scale, .number(binding.wrappedValue), armedOn: binding)
    }

    /// The horizontal half of the scale, and the state that moves it.
    /// MAUI: VisualElement.ScaleX.
    public func scaleX(_ binding: Binding<Double>) -> Modified {
        setValue(.scaleX, .number(binding.wrappedValue), armedOn: binding)
    }

    /// The vertical half of the scale, and the state that moves it.
    /// MAUI: VisualElement.ScaleY.
    public func scaleY(_ binding: Binding<Double>) -> Modified {
        setValue(.scaleY, .number(binding.wrappedValue), armedOn: binding)
    }

    /// How far the view is moved sideways from where it was laid out, and the
    /// state that moves it. MAUI: VisualElement.TranslationX.
    ///
    /// A diagonal is two states and two flights - one per axis - which start
    /// together and land together.
    public func translationX(_ binding: Binding<Double>) -> Modified {
        setValue(.translationX, .number(binding.wrappedValue), armedOn: binding)
    }

    /// How far the view is moved up or down from where it was laid out, and
    /// the state that moves it. MAUI: VisualElement.TranslationY.
    public func translationY(_ binding: Binding<Double>) -> Modified {
        setValue(.translationY, .number(binding.wrappedValue), armedOn: binding)
    }

    /// Where the horizontal centre of a rotation or a scale sits, and the
    /// state that moves it. MAUI: VisualElement.AnchorX.
    public func anchorX(_ binding: Binding<Double>) -> Modified {
        setValue(.anchorX, .number(binding.wrappedValue), armedOn: binding)
    }

    /// Where the vertical centre of a rotation or a scale sits, and the state
    /// that moves it. MAUI: VisualElement.AnchorY.
    public func anchorY(_ binding: Binding<Double>) -> Modified {
        setValue(.anchorY, .number(binding.wrappedValue), armedOn: binding)
    }
}

// MARK: - View

extension View {
    /// The space OUTSIDE the view, and the state that moves it.
    /// MAUI: View.Margin. `padding` is the space inside.
    ///
    /// Each edge walks on its own, so a flight from `Thickness(8)` to
    /// `Thickness(24, 8)` moves two of the four and leaves the others.
    public func margin(_ binding: Binding<Thickness>) -> Modified {
        setValue(.margin, binding.wrappedValue.propValue, armedOn: binding)
    }
}

// MARK: - StackBase

extension StackBase {
    /// The gap between the children, and the state that moves it.
    /// MAUI: StackBase.Spacing.
    public func spacing(_ binding: Binding<Double>) -> Modified {
        setValue(.spacing, .number(binding.wrappedValue), armedOn: binding)
    }
}

// MARK: - Shape

extension Shape {
    /// How thick the outline is drawn, and the state that moves it.
    /// MAUI: Shape.StrokeThickness.
    ///
    /// The outline's COLOUR is a brush, and nothing walks a brush - `.stroke()`
    /// takes a value, never a binding.
    public func strokeThickness(_ binding: Binding<Double>) -> Modified {
        setValue(.strokeThickness, .number(binding.wrappedValue), armedOn: binding)
    }

    /// How far into the dash pattern the outline starts, and the state that
    /// moves it. MAUI: Shape.StrokeDashOffset.
    ///
    /// Flying this is how a dashed outline is made to crawl - the marching
    /// ants - since the pattern itself holds still.
    ///
    ///     @State private var crawl = 0.0
    ///     …
    ///     Rectangle()
    ///         .stroke(.gray)
    ///         .strokeThickness(2)
    ///         .strokeDashArray([4, 2])
    ///         .strokeDashOffset($crawl)
    ///     …
    ///     try await $crawl.animateTo(6, length: 600)
    ///
    /// One pattern length is the sum of the dash array, so walking to it and
    /// starting again is a loop with no visible seam.
    public func strokeDashOffset(_ binding: Binding<Double>) -> Modified {
        setValue(.strokeDashOffset, .number(binding.wrappedValue), armedOn: binding)
    }

    /// How far a sharp corner may reach before it is cut off, and the state
    /// that moves it. MAUI: Shape.StrokeMiterLimit.
    public func strokeMiterLimit(_ binding: Binding<Double>) -> Modified {
        setValue(.strokeMiterLimit, .number(binding.wrappedValue), armedOn: binding)
    }
}

// MARK: - The mixins

extension PaddingElement where Self: VisualElement {
    /// The space INSIDE the view, around its content, and the state that moves
    /// it. MAUI: the Padding of whichever class declares one. `margin` is the
    /// space outside.
    public func padding(_ binding: Binding<Thickness>) -> Modified {
        setValue(.padding, binding.wrappedValue.propValue, armedOn: binding)
    }
}

extension FontElement where Self: VisualElement {
    /// How big the text is, and the state that moves it.
    /// MAUI: FontElement.FontSize.
    public func fontSize(_ binding: Binding<Double>) -> Modified {
        setValue(.fontSize, .number(binding.wrappedValue), armedOn: binding)
    }
}

extension TextStyleElement where Self: VisualElement {
    /// What colour the text is drawn in, and the state that moves it.
    /// MAUI: TextElement.TextColor.
    public func textColor(_ binding: Binding<Color>) -> Modified {
        setValue(.textColor, binding.wrappedValue.propValue, armedOn: binding)
    }

    /// How much air there is between the letters, and the state that moves it.
    /// MAUI: TextElement.CharacterSpacing.
    public func characterSpacing(_ binding: Binding<Double>) -> Modified {
        setValue(.characterSpacing, .number(binding.wrappedValue), armedOn: binding)
    }
}

extension BorderElement where Self: VisualElement {
    /// What colour the outline is, and the state that moves it.
    /// MAUI: IBorderElement.BorderColor.
    public func borderColor(_ binding: Binding<Color>) -> Modified {
        setValue(.borderColor, binding.wrappedValue.propValue, armedOn: binding)
    }

    /// How thick the outline is, and the state that moves it.
    /// MAUI: IBorderElement.BorderWidth.
    ///
    /// `cornerRadius` has no armed form: MAUI declares that one an `Int`, and
    /// nothing walks a whole number.
    public func borderWidth(_ binding: Binding<Double>) -> Modified {
        setValue(.borderWidth, .number(binding.wrappedValue), armedOn: binding)
    }
}

extension InputView {
    /// What colour the placeholder is drawn in, and the state that moves it.
    /// MAUI: InputView.PlaceholderColor.
    public func placeholderColor(_ binding: Binding<Color>) -> Modified {
        setValue(.placeholderColor, binding.wrappedValue.propValue, armedOn: binding)
    }
}
