// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The properties that can be driven by state: the same modifiers, taking the number
// instead of the value.
//
// Every one of these is the value form with state the host moves in place of the value, and
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
// a state change crosses as a value like any other, a number write crosses as
// nothing, and the newest of the two setpoints is the one in force.
//
// They are on the ELEMENT-side protocols - `VisualElement`, `View`,
// `StackBase`, `Shape` - and not on the `…Properties` ones the value forms sit
// on, because a `StyleBag` wears every `…Properties` protocol there is: a number
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
    ///     @State(describing: .none) private var fade = AnimatedValue(1.0)
    ///
    ///     Border { … }.opacity($fade)
    ///
    ///     fade.setPoint = 0.2                  // travels there
    ///     fade.value = 1                       // snaps
    ///     try await $fade.animateTo(0.1)       // and waits
    ///
    /// On a number, `isVisible` shows and hides AT ONCE: the fade is yours to
    /// write.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func opacity(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.opacity, on: number, mode: mode, kind: .property)
    }

    /// What is drawn behind the view. MAUI: VisualElement.BackgroundColor.
    ///
    /// A colour crosses as four lanes from nought to one, so a colour half
    /// way between two others is what the lanes say - a `Color(light:dark:)`
    /// is resolved by the tree and never by a number.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func backgroundColor(_ number: Binding<AnimatedValue<Color>>, mode: StateMode = .inOut) -> Modified {
        setValue(.backgroundColor, on: number, mode: mode, kind: .property)
    }

    /// The width asked for. MAUI: VisualElement.WidthRequest.
    ///
    /// Not `.width($:)`, which is the opposite direction - that one REPORTS
    /// the width a layout settled on and never asks for one.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func widthRequest(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.widthRequest, on: number, mode: mode, kind: .property)
    }

    /// The height asked for. MAUI: VisualElement.HeightRequest.
    ///
    /// See `widthRequest` for the trap it shares with `.height($:)`.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func heightRequest(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.heightRequest, on: number, mode: mode, kind: .property)
    }

    /// The narrowest the view may be laid out. MAUI: VisualElement.MinimumWidthRequest.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func minimumWidthRequest(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.minimumWidthRequest, on: number, mode: mode, kind: .property)
    }

    /// The shortest the view may be laid out. MAUI: VisualElement.MinimumHeightRequest.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func minimumHeightRequest(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.minimumHeightRequest, on: number, mode: mode, kind: .property)
    }

    /// The widest the view may be laid out. MAUI: VisualElement.MaximumWidthRequest.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func maximumWidthRequest(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.maximumWidthRequest, on: number, mode: mode, kind: .property)
    }

    /// The tallest the view may be laid out. MAUI: VisualElement.MaximumHeightRequest.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func maximumHeightRequest(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.maximumHeightRequest, on: number, mode: mode, kind: .property)
    }

    /// How far the view is turned in the plane of the screen, in degrees. MAUI: VisualElement.Rotation.
    ///
    /// The one turn that means the same picture on every platform, which is
    /// why a card turned away is written as a `scaleX` instead.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func rotation(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.rotation, on: number, mode: mode, kind: .property)
    }

    /// How far the view is tipped about its horizontal axis, in degrees. MAUI: VisualElement.RotationX.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func rotationX(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.rotationX, on: number, mode: mode, kind: .property)
    }

    /// How far the view is tipped about its vertical axis, in degrees. MAUI: VisualElement.RotationY.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func rotationY(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.rotationY, on: number, mode: mode, kind: .property)
    }

    /// How much bigger the view is drawn, 1 being as laid out. MAUI: VisualElement.Scale.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func scale(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.scale, on: number, mode: mode, kind: .property)
    }

    /// How much wider the view is drawn. MAUI: VisualElement.ScaleX.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func scaleX(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.scaleX, on: number, mode: mode, kind: .property)
    }

    /// How much taller the view is drawn. MAUI: VisualElement.ScaleY.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func scaleY(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.scaleY, on: number, mode: mode, kind: .property)
    }

    /// How far the view is moved sideways from where it was laid out. MAUI: VisualElement.TranslationX.
    ///
    /// What a drag is followed with: `.panX($x).translationX($x)` puts the
    /// hand and the view on ONE number, and the view then follows the finger
    /// with no arithmetic of yours at all.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func translationX(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.translationX, on: number, mode: mode, kind: .property)
    }

    /// How far the view is moved down from where it was laid out. MAUI: VisualElement.TranslationY.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func translationY(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.translationY, on: number, mode: mode, kind: .property)
    }

    /// Where across the view a turn and a scale are centred, 0.5 being the middle. MAUI: VisualElement.AnchorX.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func anchorX(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.anchorX, on: number, mode: mode, kind: .property)
    }

    /// Where down the view a turn and a scale are centred. MAUI: VisualElement.AnchorY.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func anchorY(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.anchorY, on: number, mode: mode, kind: .property)
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
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func margin(_ number: Binding<AnimatedValue<Thickness>>, mode: StateMode = .inOut) -> Modified {
        setValue(.margin, on: number, mode: mode, kind: .property)
    }
}

// MARK: - StackBase

extension StackBase {
    /// The gap between the children. MAUI: StackBase.Spacing.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func spacing(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.spacing, on: number, mode: mode, kind: .property)
    }
}

// MARK: - Shape

extension Shape {
    /// How thick the outline is drawn. MAUI: Shape.StrokeThickness.
    ///
    /// The outline's COLOUR is a brush, and no brush rides a number -
    /// `.stroke()` takes a value.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func strokeThickness(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.strokeThickness, on: number, mode: mode, kind: .property)
    }

    /// How far into the dash pattern the outline starts. MAUI: Shape.StrokeDashOffset.
    ///
    /// A number here is how a dashed outline crawls without a render: an engine
    /// adds to it every frame and the pattern marches.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func strokeDashOffset(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.strokeDashOffset, on: number, mode: mode, kind: .property)
    }

    /// How far a sharp corner may reach before it is cut off. MAUI: Shape.StrokeMiterLimit.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func strokeMiterLimit(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.strokeMiterLimit, on: number, mode: mode, kind: .property)
    }
}

// MARK: - The mixins

extension PaddingElement where Self: VisualElement {
    /// The space INSIDE the view, between its edge and what it holds. MAUI: PaddingElement.Padding.
    ///
    /// `.margin` is outside, this is inside.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func padding(_ number: Binding<AnimatedValue<Thickness>>, mode: StateMode = .inOut) -> Modified {
        setValue(.padding, on: number, mode: mode, kind: .property)
    }
}

extension FontElement where Self: VisualElement {
    /// How tall the letters are drawn, in device units. MAUI: FontElement.FontSize.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func fontSize(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.fontSize, on: number, mode: mode, kind: .property)
    }
}

extension TextStyleElement where Self: VisualElement {
    /// What colour the text is drawn in. MAUI: TextStyleElement.TextColor.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func textColor(_ number: Binding<AnimatedValue<Color>>, mode: StateMode = .inOut) -> Modified {
        setValue(.textColor, on: number, mode: mode, kind: .property)
    }

    /// How much extra room each letter is given. MAUI: TextStyleElement.CharacterSpacing.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func characterSpacing(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.characterSpacing, on: number, mode: mode, kind: .property)
    }
}

extension BorderElement where Self: VisualElement {
    /// What colour the edge is drawn in. MAUI: BorderElement.BorderColor.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func borderColor(_ number: Binding<AnimatedValue<Color>>, mode: StateMode = .inOut) -> Modified {
        setValue(.borderColor, on: number, mode: mode, kind: .property)
    }

    /// How thick the edge is drawn. MAUI: BorderElement.BorderWidth.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func borderWidth(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Modified {
        setValue(.borderWidth, on: number, mode: mode, kind: .property)
    }
}

extension InputView {
    /// What colour the placeholder is drawn in. MAUI: InputView.PlaceholderColor.
    ///
    /// - Parameters:
    ///   - number: the number it is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the element, with the property driven to that number.
    public func placeholderColor(_ number: Binding<AnimatedValue<Color>>, mode: StateMode = .inOut) -> Modified {
        setValue(.placeholderColor, on: number, mode: mode, kind: .property)
    }
}

// MARK: - Text, and the two-way inputs

// A TEXT DRIVEN STATE IS THE DOOR FOR A SHOWN NUMBER. Text is not interpolable, so
// nothing walks it: the host writes it when the number is dirty AND the bytes
// differ from the last thing it wrote, which is what makes
// Slider -> engine -> Label cost a render of nothing at all.
//
// There is no `.text` on the TextElement tier, though MAUI's own Text sits
// there: an Entry, an Editor and a SearchBar wear that protocol, and a caption
// written onto one of those from a number would land under the reader's own
// caret. Text is per class here for that reason.

extension Label {
    /// What the label says, read from a number. MAUI: Label.Text.
    ///
    ///     @State(describing: .none) private var caption = ""
    ///
    ///     Label().text($caption)
    ///     …
    ///     .following($level) { _ in
    ///         caption = "\(Int(level.value * 100))%"
    ///     }
    ///
    /// OUT ONLY, and it costs no render: the host writes the text when the
    /// bytes change and nothing else happens at all. What it costs instead is
    /// a re-measure of the label on the frame the words change, which is what
    /// any changed caption costs.
    ///
    /// - Parameter number: the number the words are read from.
    /// - Returns: the label, with its text driven to that number.
    public func text(_ number: Binding<String>) -> Label {
        setValue(.text, on: number, mode: .out, kind: .text)
    }
}

extension Button {
    /// What the button says, read from a number. MAUI: Button.Text.
    ///
    /// Out only, and written when the bytes change - see `Label.text(_:)`.
    ///
    /// - Parameter number: the number the caption is read from.
    /// - Returns: the button, with its caption driven to that number.
    public func text(_ number: Binding<String>) -> Button {
        setValue(.text, on: number, mode: .out, kind: .text)
    }
}

extension Slider {
    /// Where the thumb stands, on a number. MAUI: Slider.Value.
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
    /// the binding is state, so every report renders; the number is not, so none
    /// of them does. A slider that is both is a slider whose value the tree
    /// shows and whose thumb an engine can move.
    ///
    /// - Parameters:
    ///   - number: the number the value is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the slider, with its value driven to that number.
    public func value(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Slider {
        setValue(.value, on: number, mode: mode, kind: .property)
    }
}

extension Stepper {
    /// Where the stepper stands, on a number. MAUI: Stepper.Value.
    ///
    /// Both ways, as a slider's is - and with the same rule about a report
    /// that arrives from outside the engine's write being the reader's. A
    /// stepper has no dragging to report, so every report it makes is one.
    ///
    /// - Parameters:
    ///   - number: the number the value is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the stepper, with its value driven to that number.
    public func value(_ number: Binding<AnimatedValue<Double>>, mode: StateMode = .inOut) -> Stepper {
        setValue(.value, on: number, mode: mode, kind: .property)
    }
}

extension BoxView {
    /// What the rectangle is filled with, read from a number. MAUI: BoxView.Color.
    ///
    /// Not `.backgroundColor`, for the reason `color(_:)` gives: the
    /// background is a second square behind the one a box draws.
    ///
    /// - Parameters:
    ///   - number: the number the colour is read from.
    ///   - mode: which way it crosses. Both unless said.
    /// - Returns: the box, with its colour driven to that number.
    public func color(_ number: Binding<AnimatedValue<Color>>, mode: StateMode = .inOut) -> BoxView {
        setValue(.color, on: number, mode: mode, kind: .property)
    }
}

// MARK: - The feeds

extension VisualElement {
    /// The room the platform gave the view, written onto a number whenever it
    /// changes. MAUI: VisualElement.Frame.
    ///
    ///     @State(describing: .none) private var room = Rect(0, 0, 0, 0)
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
    /// - Parameter number: the number the room is written onto.
    /// - Returns: the element, reporting its room there.
    public func frame(_ number: Binding<Rect>) -> Modified {
        setValue(.frame, on: number, mode: .in, kind: .feed)
    }
}
