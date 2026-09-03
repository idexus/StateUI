// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The properties that can be tied to a BUS: the same modifiers, taking the bus
// instead of the value.
//
// Every one of these is the value form with a `Bus` in place of the value, and
// every one is one line over `setValue(_:on:mode:kind:)`. What they mean is one
// sentence, and it is the same sentence for all thirty:
//
//   NO VALUE CROSSES. The host reads the property off the image on its own
//   frames - `setPoint` says where it is going and the engine carries it there,
//   `value` written instead is a snap, `velocity` is a kick - and no message
//   after the registration mentions this property at all. So a value moving
//   forty times a second costs the arithmetic and nothing else.
//
// Beside a STATED value the two stand together (`.opacity(dim).opacity($fade)`):
// a state change crosses as a value like any other, a bus write crosses as
// nothing, and the newest of the two setpoints is the one in force.
//
// They are on the ELEMENT-side protocols - `VisualElement`, `View`,
// `StackBase`, `Shape` - and not on the `…Properties` ones the value forms sit
// on, because a `StyleBag` wears every `…Properties` protocol there is: a bus
// written where the value form sits would appear inside `Style<Label>`, where
// it would compile and mean nothing. The mixins have no element-side twin, so
// they are constrained `where Self: VisualElement`.
//
// THE MODE is `.inOut` for every one of them, which is what a property that
// can be both written and read back is: `.out` refuses what the platform
// reports, and `.in` reads where the platform has it and refuses what this side
// writes. An attachment with only one direction to it - a placement, a frame,
// a drag - takes no mode at all, because an argument that cannot change lies.

// MARK: - VisualElement

extension VisualElement {
    /// How opaque the view is, from 0 to 1. MAUI: VisualElement.Opacity.
    ///
    ///     @Bus private var fade = AnimatedValue(1.0)
    ///
    ///     Border { … }.opacity($fade)
    ///
    ///     fade.setPoint = 0.2                  // travels there
    ///     fade.value = 1                       // snaps
    ///     try await $fade.animateTo(0.1)       // and waits
    ///
    /// On a bus, `isVisible` shows and hides AT ONCE: the fade is yours to
    /// write.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func opacity(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.opacity, on: bus, mode: mode, kind: .property)
    }

    /// What is drawn behind the view. MAUI: VisualElement.BackgroundColor.
    ///
    /// A colour crosses as four lanes from nought to one, so a colour half
    /// way between two others is what the lanes say - a `Color(light:dark:)`
    /// is resolved by the tree and never by a bus.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func backgroundColor(_ bus: Bus<AnimatedValue<Color>>, mode: BusMode = .inOut) -> Modified {
        setValue(.backgroundColor, on: bus, mode: mode, kind: .property)
    }

    /// The width asked for. MAUI: VisualElement.WidthRequest.
    ///
    /// Not `.width($:)`, which is the opposite direction - that one REPORTS
    /// the width a layout settled on and never asks for one.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func widthRequest(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.widthRequest, on: bus, mode: mode, kind: .property)
    }

    /// The height asked for. MAUI: VisualElement.HeightRequest.
    ///
    /// See `widthRequest` for the trap it shares with `.height($:)`.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func heightRequest(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.heightRequest, on: bus, mode: mode, kind: .property)
    }

    /// The narrowest the view may be laid out. MAUI: VisualElement.MinimumWidthRequest.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func minimumWidthRequest(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.minimumWidthRequest, on: bus, mode: mode, kind: .property)
    }

    /// The shortest the view may be laid out. MAUI: VisualElement.MinimumHeightRequest.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func minimumHeightRequest(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.minimumHeightRequest, on: bus, mode: mode, kind: .property)
    }

    /// The widest the view may be laid out. MAUI: VisualElement.MaximumWidthRequest.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func maximumWidthRequest(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.maximumWidthRequest, on: bus, mode: mode, kind: .property)
    }

    /// The tallest the view may be laid out. MAUI: VisualElement.MaximumHeightRequest.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func maximumHeightRequest(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.maximumHeightRequest, on: bus, mode: mode, kind: .property)
    }

    /// How far the view is turned in the plane of the screen, in degrees. MAUI: VisualElement.Rotation.
    ///
    /// The one turn that means the same picture on every platform, which is
    /// why a card turned away is written as a `scaleX` instead.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func rotation(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.rotation, on: bus, mode: mode, kind: .property)
    }

    /// How far the view is tipped about its horizontal axis, in degrees. MAUI: VisualElement.RotationX.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func rotationX(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.rotationX, on: bus, mode: mode, kind: .property)
    }

    /// How far the view is tipped about its vertical axis, in degrees. MAUI: VisualElement.RotationY.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func rotationY(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.rotationY, on: bus, mode: mode, kind: .property)
    }

    /// How much bigger the view is drawn, 1 being as laid out. MAUI: VisualElement.Scale.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func scale(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.scale, on: bus, mode: mode, kind: .property)
    }

    /// How much wider the view is drawn. MAUI: VisualElement.ScaleX.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func scaleX(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.scaleX, on: bus, mode: mode, kind: .property)
    }

    /// How much taller the view is drawn. MAUI: VisualElement.ScaleY.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func scaleY(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.scaleY, on: bus, mode: mode, kind: .property)
    }

    /// How far the view is moved sideways from where it was laid out. MAUI: VisualElement.TranslationX.
    ///
    /// What a drag is followed with: `.panX($x).translationX($x)` puts the
    /// hand and the view on ONE bus, and the view then follows the finger
    /// with no arithmetic of yours at all.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func translationX(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.translationX, on: bus, mode: mode, kind: .property)
    }

    /// How far the view is moved down from where it was laid out. MAUI: VisualElement.TranslationY.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func translationY(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.translationY, on: bus, mode: mode, kind: .property)
    }

    /// Where across the view a turn and a scale are centred, 0.5 being the middle. MAUI: VisualElement.AnchorX.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func anchorX(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.anchorX, on: bus, mode: mode, kind: .property)
    }

    /// Where down the view a turn and a scale are centred. MAUI: VisualElement.AnchorY.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func anchorY(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.anchorY, on: bus, mode: mode, kind: .property)
    }
}

// MARK: - View

extension View {
    /// The space OUTSIDE the view, between it and its neighbours. MAUI: View.Margin.
    ///
    /// Four lanes - left, top, right, bottom - so one side moves without the
    /// others crossing at all.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func margin(_ bus: Bus<AnimatedValue<Thickness>>, mode: BusMode = .inOut) -> Modified {
        setValue(.margin, on: bus, mode: mode, kind: .property)
    }
}

// MARK: - StackBase

extension StackBase {
    /// The gap between the children. MAUI: StackBase.Spacing.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func spacing(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.spacing, on: bus, mode: mode, kind: .property)
    }
}

// MARK: - Shape

extension Shape {
    /// How thick the outline is drawn. MAUI: Shape.StrokeThickness.
    ///
    /// The outline's COLOUR is a brush, and no brush rides a bus -
    /// `.stroke()` takes a value.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func strokeThickness(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.strokeThickness, on: bus, mode: mode, kind: .property)
    }

    /// How far into the dash pattern the outline starts. MAUI: Shape.StrokeDashOffset.
    ///
    /// A bus here is how a dashed outline crawls without a render: an engine
    /// adds to it every frame and the pattern marches.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func strokeDashOffset(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.strokeDashOffset, on: bus, mode: mode, kind: .property)
    }

    /// How far a sharp corner may reach before it is cut off. MAUI: Shape.StrokeMiterLimit.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func strokeMiterLimit(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.strokeMiterLimit, on: bus, mode: mode, kind: .property)
    }
}

// MARK: - The mixins

extension PaddingElement where Self: VisualElement {
    /// The space INSIDE the view, between its edge and what it holds. MAUI: PaddingElement.Padding.
    ///
    /// `.margin` is outside, this is inside.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func padding(_ bus: Bus<AnimatedValue<Thickness>>, mode: BusMode = .inOut) -> Modified {
        setValue(.padding, on: bus, mode: mode, kind: .property)
    }
}

extension FontElement where Self: VisualElement {
    /// How tall the letters are drawn, in device units. MAUI: FontElement.FontSize.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func fontSize(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.fontSize, on: bus, mode: mode, kind: .property)
    }
}

extension TextStyleElement where Self: VisualElement {
    /// What colour the text is drawn in. MAUI: TextStyleElement.TextColor.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func textColor(_ bus: Bus<AnimatedValue<Color>>, mode: BusMode = .inOut) -> Modified {
        setValue(.textColor, on: bus, mode: mode, kind: .property)
    }

    /// How much extra room each letter is given. MAUI: TextStyleElement.CharacterSpacing.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func characterSpacing(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.characterSpacing, on: bus, mode: mode, kind: .property)
    }
}

extension BorderElement where Self: VisualElement {
    /// What colour the edge is drawn in. MAUI: BorderElement.BorderColor.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func borderColor(_ bus: Bus<AnimatedValue<Color>>, mode: BusMode = .inOut) -> Modified {
        setValue(.borderColor, on: bus, mode: mode, kind: .property)
    }

    /// How thick the edge is drawn. MAUI: BorderElement.BorderWidth.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func borderWidth(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Modified {
        setValue(.borderWidth, on: bus, mode: mode, kind: .property)
    }
}

extension InputView {
    /// What colour the placeholder is drawn in. MAUI: InputView.PlaceholderColor.
    ///
    /// - Parameters:
    ///   - bus: the bus it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property tied to that bus.
    public func placeholderColor(_ bus: Bus<AnimatedValue<Color>>, mode: BusMode = .inOut) -> Modified {
        setValue(.placeholderColor, on: bus, mode: mode, kind: .property)
    }
}

// MARK: - Text, and the two-way inputs

// A TEXT BUS IS THE DOOR FOR A SHOWN NUMBER. Text is not interpolable, so
// nothing walks it: the host writes it when the bus is dirty AND the bytes
// differ from the last thing it wrote, which is what makes
// Slider -> engine -> Label cost a render of nothing at all.
//
// There is no `.text` on the TextElement tier, though MAUI's own Text sits
// there: an Entry, an Editor and a SearchBar wear that protocol, and a caption
// written onto one of those from a bus would land under the reader's own
// caret. Text is per class here for that reason.

extension Label {
    /// What the label says, read from a bus. MAUI: Label.Text.
    ///
    ///     @Bus private var caption = ""
    ///
    ///     Label().text($caption)
    ///     …
    ///     .engine(following: $level) { _ in
    ///         caption = "\(Int(level.value * 100))%"
    ///     }
    ///
    /// OUT ONLY, and it costs no render: the host writes the text when the
    /// bytes change and nothing else happens at all. What it costs instead is
    /// a re-measure of the label on the frame the words change, which is what
    /// any changed caption costs.
    ///
    /// - Parameter bus: the bus the words are read from.
    /// - Returns: the label, with its text tied to that bus.
    public func text(_ bus: Bus<String>) -> Label {
        setValue(.text, on: bus, mode: .out, kind: .text)
    }
}

extension Button {
    /// What the button says, read from a bus. MAUI: Button.Text.
    ///
    /// Out only, and written when the bytes change - see `Label.text(_:)`.
    ///
    /// - Parameter bus: the bus the caption is read from.
    /// - Returns: the button, with its caption tied to that bus.
    public func text(_ bus: Bus<String>) -> Button {
        setValue(.text, on: bus, mode: .out, kind: .text)
    }
}

extension Slider {
    /// Where the thumb stands, on a bus. MAUI: Slider.Value.
    ///
    ///     Slider($volume).value($level)
    ///
    /// BOTH WAYS by default: the platform writes the reader's drag into
    /// `value` and their release into `velocity`, and a `setPoint` written
    /// here moves the thumb. A finger landing on a moving thumb TAKES it - the
    /// report arrives from outside the engine's own write, which is what says
    /// it is the reader's.
    ///
    /// It stands beside `Slider($volume)`, and the two are not the same thing:
    /// the binding is state, so every report renders; the bus is not, so none
    /// of them does. A slider that is both is a slider whose value the tree
    /// shows and whose thumb an engine can move.
    ///
    /// - Parameters:
    ///   - bus: the bus the value is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the slider, with its value tied to that bus.
    public func value(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Slider {
        setValue(.value, on: bus, mode: mode, kind: .property)
    }
}

extension Stepper {
    /// Where the stepper stands, on a bus. MAUI: Stepper.Value.
    ///
    /// Both ways, as a slider's is - and with the same rule about a report
    /// that arrives from outside the engine's write being the reader's. A
    /// stepper has no dragging to report, so every report it makes is one.
    ///
    /// - Parameters:
    ///   - bus: the bus the value is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the stepper, with its value tied to that bus.
    public func value(_ bus: Bus<AnimatedValue<Double>>, mode: BusMode = .inOut) -> Stepper {
        setValue(.value, on: bus, mode: mode, kind: .property)
    }
}
