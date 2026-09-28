// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The properties the host writes from a state that are not a value modifier's
// twin: the words a label or a button shows, and the feeds the platform
// reports into a state.
// Design: docs/design/views/bindings.md#driven-text

extension Label {
    /// What the label says, carried from a state: the host writes the text as
    /// it changes, with no view rebuilt - only the label measured again.
    ///
    ///     @State private var caption = ""
    ///
    ///     Label().text($caption)
    ///     …
    ///     .engine(following: $level) { _ in
    ///         caption = "\(Int($level.journey.value * 100))%"
    ///     }
    ///
    /// - Parameter state: the state the words are read from.
    /// - Returns: the label, with its text carried from that state.
    public func text(_ state: Binding<String>) -> Label {
        setValue(TextElementContract.text, on: state, mode: .out, kind: .text)
    }
}

extension Button {
    /// What the button says, carried from a state; see `Label.text(_:)`.
    ///
    /// - Parameter state: the state the caption is read from.
    /// - Returns: the button, with its caption carried from that state.
    public func text(_ state: Binding<String>) -> Button {
        setValue(TextElementContract.text, on: state, mode: .out, kind: .text)
    }
}

// MARK: - The feeds

extension VisualElement {
    /// The frame the platform gave the view - where it sits in its parent and
    /// how big it is - written into a state as it changes, with no view rebuilt.
    ///
    ///     @State private var room = Rect(0, 0, 0, 0)
    ///
    ///     PlacedLayout(cards, id: \.name) { face($0) }
    ///         .placement($run)
    ///         .frame($room)
    ///
    /// For arithmetic that lays views out; `FrameReader` is for content built
    /// from the frame. Writing the state moves nothing: the frame is the
    /// layout's answer. A layout reporting its frame gives its children their
    /// new sizes at once, and a size worked out from the frame elsewhere wants
    /// `.motion(.none)`.
    ///
    /// - Parameter state: the state the frame is written into.
    /// - Returns: the element, reporting its frame there.
    public func frame(_ state: Binding<Rect>) -> Modified {
        setValue(VisualElementContract.frame, on: state, mode: .in, kind: .feed)
    }
}
