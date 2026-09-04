// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The properties that can be driven by state: the same modifiers, taking the
// state instead of the value.
//
// Every one of these is the value form with state the host moves in place of the value, and
// every one is one line over `setValue(_:on:mode:kind:)`. What they mean is one
// sentence, and it is the same sentence for all of them:
//
//   NO VALUE CROSSES. The host reads the property off the image on its own
//   frames - `setPoint` says where it is going and the engine carries it there,
//   `value` written instead is a snap, `velocity` is a kick - and no message
//   after the registration mentions this property at all. So a value moving
//   forty times a second costs the arithmetic and nothing else.
//
// Beside a STATED value the two stand together (`.opacity(dim).opacity($fade)`):
// a state change crosses as a value like any other, a driven write crosses as
// nothing, and the newest of the two setpoints is the one in force.
//
// They are on the ELEMENT-side protocols - `VisualElement`, `View`,
// `StackBase`, `Shape` - and not on the `…Properties` ones the value forms sit
// on, because a `StyleBag` wears every `…Properties` protocol there is: one
// written where the value form sits would appear inside `Style<Label>`, where
// it would compile and mean nothing. The mixins have no element-side twin, so
// they are constrained `where Self: VisualElement`.
//
// NONE OF THEM TAKES A MODE, because an argument that cannot change lies. The
// mode is `.inOut` for every PROPERTY here, and that is not a default anybody
// would sensibly override: an `AnimatedValue`'s `value` MEANS where the value
// is, so a property the host carries has to say where it got to or the value
// is untrue. `.out` refuses what the platform reports and would make it so.
//
// The other two modes are still real, and are stated by whoever knows: a
// PLACEMENT and a text are `.out` - there is no walk to report - and a FRAME is
// `.in`, the host telling the state where the layout put the view. An
// application registering a control of its own picks for it, on the public
// `setValue(_:on:mode:kind:)`, because only that application knows whether its
// property is one the platform answers.

// MARK: - VisualElement

extension VisualElement {
    /// How opaque the view is, from 0 to 1. MAUI: VisualElement.Opacity.
    ///
    ///     @DrivenState private var fade = AnimatedValue(1.0)
    ///
    ///     Border { … }.opacity($fade)
    ///
    ///     fade.setPoint = 0.2                  // travels there
    ///     fade.value = 1                       // snaps
    ///     try await $fade.animateTo(0.1)       // and waits
    ///
    /// Driven, `isVisible` shows and hides AT ONCE: the fade is yours to
    /// write.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func opacity(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.opacity, on: state, mode: .inOut, kind: .property)
    }

    /// What is drawn behind the view. MAUI: VisualElement.BackgroundColor.
    ///
    /// A colour crosses as four lanes from nought to one, so a colour half
    /// way between two others is what the lanes say.
    ///
    /// **A `Color(light:dark:)` DRIVEN THIS WAY RIDES ITS LIGHT HALF.** Only
    /// the tree-described path resolves the theme, because only a render knows
    /// which half is wanted and can be rebuilt when the reader changes it -
    /// there is no render here at all. Write the resolved colour into the
    /// state instead, from a body that read the theme.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func backgroundColor(_ state: Binding<AnimatedValue<Color>>) -> Modified {
        setValue(.backgroundColor, on: state, mode: .inOut, kind: .property)
    }

    /// The width asked for. MAUI: VisualElement.WidthRequest.
    ///
    /// Not `.width($:)`, which is the opposite direction - that one REPORTS
    /// the width a layout settled on and never asks for one.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func widthRequest(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.widthRequest, on: state, mode: .inOut, kind: .property)
    }

    /// The height asked for. MAUI: VisualElement.HeightRequest.
    ///
    /// See `widthRequest` for the trap it shares with `.height($:)`.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func heightRequest(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.heightRequest, on: state, mode: .inOut, kind: .property)
    }

    /// The narrowest the view may be laid out. MAUI: VisualElement.MinimumWidthRequest.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func minimumWidthRequest(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.minimumWidthRequest, on: state, mode: .inOut, kind: .property)
    }

    /// The shortest the view may be laid out. MAUI: VisualElement.MinimumHeightRequest.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func minimumHeightRequest(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.minimumHeightRequest, on: state, mode: .inOut, kind: .property)
    }

    /// The widest the view may be laid out. MAUI: VisualElement.MaximumWidthRequest.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func maximumWidthRequest(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.maximumWidthRequest, on: state, mode: .inOut, kind: .property)
    }

    /// The tallest the view may be laid out. MAUI: VisualElement.MaximumHeightRequest.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func maximumHeightRequest(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.maximumHeightRequest, on: state, mode: .inOut, kind: .property)
    }

    /// How far the view is turned in the plane of the screen, in degrees. MAUI: VisualElement.Rotation.
    ///
    /// The one turn that means the same picture on every platform, which is
    /// why a card turned away is written as a `scaleX` instead.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func rotation(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.rotation, on: state, mode: .inOut, kind: .property)
    }

    /// How far the view is tipped about its horizontal axis, in degrees. MAUI: VisualElement.RotationX.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func rotationX(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.rotationX, on: state, mode: .inOut, kind: .property)
    }

    /// How far the view is tipped about its vertical axis, in degrees. MAUI: VisualElement.RotationY.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func rotationY(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.rotationY, on: state, mode: .inOut, kind: .property)
    }

    /// How much bigger the view is drawn, 1 being as laid out. MAUI: VisualElement.Scale.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func scale(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.scale, on: state, mode: .inOut, kind: .property)
    }

    /// How much wider the view is drawn. MAUI: VisualElement.ScaleX.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func scaleX(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.scaleX, on: state, mode: .inOut, kind: .property)
    }

    /// How much taller the view is drawn. MAUI: VisualElement.ScaleY.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func scaleY(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.scaleY, on: state, mode: .inOut, kind: .property)
    }

    /// How far the view is moved sideways from where it was laid out. MAUI: VisualElement.TranslationX.
    ///
    /// What a drag is followed with: `.panX($x).translationX($x)` puts the
    /// hand and the view on ONE state, and the view then follows the finger
    /// with no arithmetic of yours at all.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func translationX(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.translationX, on: state, mode: .inOut, kind: .property)
    }

    /// How far the view is moved down from where it was laid out. MAUI: VisualElement.TranslationY.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func translationY(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.translationY, on: state, mode: .inOut, kind: .property)
    }

    /// Where across the view a turn and a scale are centred, 0.5 being the middle. MAUI: VisualElement.AnchorX.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func anchorX(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.anchorX, on: state, mode: .inOut, kind: .property)
    }

    /// Where down the view a turn and a scale are centred. MAUI: VisualElement.AnchorY.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func anchorY(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.anchorY, on: state, mode: .inOut, kind: .property)
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
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func margin(_ state: Binding<AnimatedValue<Thickness>>) -> Modified {
        setValue(.margin, on: state, mode: .inOut, kind: .property)
    }
}

// MARK: - StackBase

extension StackBase {
    /// The gap between the children. MAUI: StackBase.Spacing.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func spacing(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.spacing, on: state, mode: .inOut, kind: .property)
    }
}

// MARK: - Shape

extension Shape {
    /// How thick the outline is drawn. MAUI: Shape.StrokeThickness.
    ///
    /// The outline's COLOUR is a brush, and no brush is driven -
    /// `.stroke()` takes a value.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func strokeThickness(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.strokeThickness, on: state, mode: .inOut, kind: .property)
    }

    /// How far into the dash pattern the outline starts. MAUI: Shape.StrokeDashOffset.
    ///
    /// Driving it is how a dashed outline crawls without a render: an engine
    /// adds to it every frame and the pattern marches.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func strokeDashOffset(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.strokeDashOffset, on: state, mode: .inOut, kind: .property)
    }

    /// How far a sharp corner may reach before it is cut off. MAUI: Shape.StrokeMiterLimit.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func strokeMiterLimit(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.strokeMiterLimit, on: state, mode: .inOut, kind: .property)
    }
}

// MARK: - The mixins

extension PaddingElement where Self: VisualElement {
    /// The space INSIDE the view, between its edge and what it holds. MAUI: PaddingElement.Padding.
    ///
    /// `.margin` is outside, this is inside.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func padding(_ state: Binding<AnimatedValue<Thickness>>) -> Modified {
        setValue(.padding, on: state, mode: .inOut, kind: .property)
    }
}

extension FontElement where Self: VisualElement {
    /// How tall the letters are drawn, in device units. MAUI: FontElement.FontSize.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func fontSize(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.fontSize, on: state, mode: .inOut, kind: .property)
    }
}

extension TextStyleElement where Self: VisualElement {
    /// What colour the text is drawn in. MAUI: TextStyleElement.TextColor.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func textColor(_ state: Binding<AnimatedValue<Color>>) -> Modified {
        setValue(.textColor, on: state, mode: .inOut, kind: .property)
    }

    /// How much extra room each letter is given. MAUI: TextStyleElement.CharacterSpacing.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func characterSpacing(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.characterSpacing, on: state, mode: .inOut, kind: .property)
    }
}

extension BorderElement where Self: VisualElement {
    /// What colour the edge is drawn in. MAUI: BorderElement.BorderColor.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func borderColor(_ state: Binding<AnimatedValue<Color>>) -> Modified {
        setValue(.borderColor, on: state, mode: .inOut, kind: .property)
    }

    /// How thick the edge is drawn. MAUI: BorderElement.BorderWidth.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func borderWidth(_ state: Binding<AnimatedValue<Double>>) -> Modified {
        setValue(.borderWidth, on: state, mode: .inOut, kind: .property)
    }
}

extension InputView {
    /// What colour the placeholder is drawn in. MAUI: InputView.PlaceholderColor.
    ///
    /// - Parameters:
    ///   - state: the state it is read from.
    /// - Returns: the element, with the property driven by that state.
    public func placeholderColor(_ state: Binding<AnimatedValue<Color>>) -> Modified {
        setValue(.placeholderColor, on: state, mode: .inOut, kind: .property)
    }
}

// MARK: - Text, and the two-way inputs

// A TEXT DRIVEN STATE IS THE DOOR FOR A SHOWN NUMBER. Text is not interpolable, so
// nothing walks it: the host writes it when the state is dirty AND the bytes
// differ from the last thing it wrote, which is what makes
// Slider -> engine -> Label cost a render of nothing at all.
//
// There is no `.text` on the TextElement tier, though MAUI's own Text sits
// there: an Entry, an Editor and a SearchBar wear that protocol, and a caption
// written onto one of those from a driven state would land under the reader's own
// caret. Text is per class here for that reason.

extension Label {
    /// What the label says, read from state. MAUI: Label.Text.
    ///
    ///     @DrivenState private var caption = ""
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
    /// - Parameter state: the state the words are read from.
    /// - Returns: the label, with its text driven by that state.
    public func text(_ state: Binding<String>) -> Label {
        setValue(.text, on: state, mode: .out, kind: .text)
    }
}

extension Button {
    /// What the button says, read from state. MAUI: Button.Text.
    ///
    /// Out only, and written when the bytes change - see `Label.text(_:)`.
    ///
    /// - Parameter state: the state the caption is read from.
    /// - Returns: the button, with its caption driven by that state.
    public func text(_ state: Binding<String>) -> Button {
        setValue(.text, on: state, mode: .out, kind: .text)
    }
}

extension Slider {
    /// Where the thumb stands, driven. MAUI: Slider.Value.
    ///
    ///     Slider($volume).value($level)
    ///
    /// BOTH WAYS: a `setPoint` written here moves the thumb, and the reader's
    /// own drag is written back onto `value` and `setPoint` together, so
    /// nothing aims the thumb out from under the hand holding it. What tells
    /// the two apart is WHEN the platform's report arrives - one raised inside
    /// the host's own write is the host hearing itself and is dropped.
    ///
    /// **A FINGER DOES NOT TAKE A THUMB THAT IS ALREADY MOVING.** Measured on
    /// Mac Catalyst: while the host is writing the value every frame, a drag
    /// on that thumb raises NO report at all - 47 reports during one journey,
    /// every one of them the host's own - so the journey runs to where it was
    /// sent. Stop it first if the reader is meant to be able to interrupt it.
    ///
    /// It stands beside `Slider($volume)`, and the two are not the same thing:
    /// the binding is described, so every report renders; the driven state is not, so none
    /// of them does. A slider that is both is a slider whose value the tree
    /// shows and whose thumb an engine can move.
    ///
    /// - Parameters:
    ///   - state: the state the value is read from.
    /// - Returns: the slider, with its value driven by that state.
    public func value(_ state: Binding<AnimatedValue<Double>>) -> Slider {
        setValue(.value, on: state, mode: .inOut, kind: .property)
    }
}

extension Stepper {
    /// Where the stepper stands, driven. MAUI: Stepper.Value.
    ///
    /// Both ways, as a slider's is, and by the same rule: a report raised
    /// inside the host's own write is the host hearing itself, and one raised
    /// outside it is the reader's. A stepper has no dragging to report, so
    /// every report it makes at rest is a press.
    ///
    /// - Parameters:
    ///   - state: the state the value is read from.
    /// - Returns: the stepper, with its value driven by that state.
    public func value(_ state: Binding<AnimatedValue<Double>>) -> Stepper {
        setValue(.value, on: state, mode: .inOut, kind: .property)
    }
}

extension BoxView {
    /// What the rectangle is filled with, read from state. MAUI: BoxView.Color.
    ///
    /// Not `.backgroundColor`, for the reason `color(_:)` gives: the
    /// background is a second square behind the one a box draws.
    ///
    /// - Parameters:
    ///   - state: the state the colour is read from.
    /// - Returns: the box, with its colour driven by that state.
    public func color(_ state: Binding<AnimatedValue<Color>>) -> BoxView {
        setValue(.color, on: state, mode: .inOut, kind: .property)
    }
}

// MARK: - The feeds

extension VisualElement {
    /// The room the platform gave the view, written onto state whenever it
    /// changes. MAUI: VisualElement.Frame.
    ///
    ///     @DrivenState private var room = Rect(0, 0, 0, 0)
    ///
    ///     PlacedLayout(cards, id: \.name) { face($0) }
    ///         .placement($run)
    ///         .frame($room)
    ///
    /// FOUR LANES: where the view sits in its parent, and how big it is. It is
    /// what arithmetic that lays views out has to have, and reading it this
    /// way costs no render - which is the difference between this and
    /// `FrameReader`, whose answer is a value the tree can SHOW.
    ///
    /// The host writes it and nothing this side writes reaches the platform: a
    /// view's frame is the layout's answer, not the author's.
    ///
    /// **A ROOM READ THIS WAY DOES NOT MAKE THE VIEW A MEASURED ONE.** A layout
    /// whose frame is WATCHED - which is what `onFrameChanged` makes it - places
    /// its children at once instead of carrying them there, because what a
    /// measurement reports is what the views beside a child leave it. This feed
    /// buys the room without that, so a layout arranged from what it reads here
    /// wants an `onFrameChanged` on it as well, and a size worked out from the
    /// room wants `.motion(.none)` or a value written where it stands.
    ///
    /// - Parameter state: the state the room is written onto.
    /// - Returns: the element, reporting its room there.
    public func frame(_ state: Binding<Rect>) -> Modified {
        setValue(.frame, on: state, mode: .in, kind: .feed)
    }
}
