// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// THE PROPERTIES THE HOST WRITES FROM A STATE THAT ARE NOT A VALUE MODIFIER'S
// TWIN: the words a label or a button shows, and the feeds - what the platform
// reports INTO a state. The twins themselves - every value modifier handed
// `$x` in place of its value - are in Views/Bound.swift, generated from the
// value forms, and one sentence covers all of them:
//
//   NO VALUE CROSSES. The host reads the property off the image on its own
//   frames - the state's own value says where it is going and the engine
//   carries it there, `$x.journey.value` written is a snap, `velocity` a kick
//   - and no message after the registration mentions this property at all.
//   So a value moving forty times a second costs the arithmetic and nothing
//   else.
//
// Beside a STATED value the two stand together (`.opacity(dim).opacity($fade)`):
// a state change crosses as a value like any other, a driven write crosses as
// nothing, and the newest of the two destinations is the one in force.
//
// They are on the ELEMENT-side protocols - `VisualElement`, `View`,
// `StackBase`, `Shape`, `InputView`, and the control itself where the property
// is one control's own - and not on the `…Properties` ones the value forms sit
// on, because a `StyleBag` wears every `…Properties` protocol there is: one
// written where the value form sits would appear inside `Style<Label>`, where
// it would compile and mean nothing. The mixins have no element-side twin, so
// they are constrained `where Self: VisualElement`.
//
// NONE OF THEM TAKES A MODE, because an argument that cannot change lies. The
// mode is `.inOut` for every PROPERTY the host walks, and that is not a
// default anybody would sensibly override: a journey's `value` MEANS where
// the value is, so a property the host carries has to say where it got to or
// the value is untrue. `.out` refuses what the platform reports and would make
// it so.
//
// The other two modes are still real, and are stated by whoever knows: a
// PLACEMENT and a text are `.out` - there is no walk to report - and a FRAME is
// `.in`, the host telling the state where the layout put the view. An
// application registering a control of its own picks for it, on the public
// `setValue(_:on:mode:kind:)`, because only that application knows whether its
// property is one the platform answers.


// MARK: - Text, and the two-way inputs

// A TEXT DRIVEN STATE IS THE DOOR FOR A SHOWN NUMBER. Text is not interpolable, so
// nothing walks it: the host writes it when the state is dirty AND the bytes
// differ from the last thing it wrote, which is what makes
// Slider -> engine -> Label cost a render of nothing at all.
//
// There is no driven `.text` on the `TextElement` tier, though the value form
// sits there: a Label's and a Button's text is OUT, written by the host and
// reported by nobody, where an Entry's, an Editor's and a SearchBar's is BOTH
// WAYS - the reader types into it, and the typed words land on the state as
// the host's own write - and is each field's own `text(_:)`. Text is per class
// here for that reason.

extension Label {
    /// What the label says, read from state. MAUI: Label.Text.
    ///
    ///     @State private var caption = ""
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

// MARK: - The feeds

extension VisualElement {
    /// The room the platform gave the view, written onto state whenever it
    /// changes. MAUI: VisualElement.Frame.
    ///
    ///     @State private var room = Rect(0, 0, 0, 0)
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
