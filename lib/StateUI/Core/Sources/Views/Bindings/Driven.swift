// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The properties the host writes from a state that are not a value modifier's
// twin: the words a label or a button shows, and the feeds the platform
// reports into a state.
// Design: docs/design/views/bindings.md#driven-text

extension Text {
    /// The words carried from a state - what `Text(_:)` of a state writes.
    func text(_ state: Binding<String>) -> Text {
        setValue(TextElementContract.text, on: state, as: .oneWay)
    }
}

extension Button {
    /// What the button says, carried from a state: the host writes the text as it changes, with no view rebuilt -
    /// what `Button(_:)` of a state writes.
    func text(_ state: Binding<String>) -> Button {
        setValue(TextElementContract.text, on: state, as: .oneWay)
    }
}

extension CheckBox {
    /// What the check box says beside its box, carried from a state - what `CheckBox(_:isOn:)` of a state writes.
    func text(_ state: Binding<String>) -> CheckBox {
        setValue(TextElementContract.text, on: state, as: .oneWay)
    }
}

extension Switch {
    /// What the switch says beside it, carried from a state - what `Switch(_:isOn:)` of a state writes.
    func text(_ state: Binding<String>) -> Switch {
        setValue(TextElementContract.text, on: state, as: .oneWay)
    }
}

// MARK: - The feeds

extension VisualElement {
    /// The frame the platform gave the view - where it sits in its parent and
    /// how big it is - written into a state as it changes, with no view rebuilt.
    ///
    ///     @State private var room = Rect.zero
    ///     @State private var columns = 1.0
    ///
    ///     Grid { tiles }
    ///         .frame(into: $room)
    ///         .engine(following: $room) { _ in columns = max((room.width / 240).rounded(.down), 1) }
    ///
    /// For arithmetic that lays views out; `GeometryReader` is for content built
    /// from the frame. Writing the state moves nothing: the frame is the
    /// layout's answer. Reading a frame changes nothing of how a view moves:
    /// `.layout` is where its layout puts it, at once, and `.presentation` the
    /// rectangle around what is drawn of it on the way there and under its own
    /// transform. A size worked out from a frame elsewhere wants the layout's.
    ///
    /// - Parameters:
    ///   - state: the state the frame is written into.
    ///   - stage: which rectangle - the layout's unless said.
    /// - Returns: the element, reporting its frame there.
    public func frame(into state: Binding<Rect>, stage: GeometryStage = .layout) -> Modified {
        let feed = stage == .layout ? VisualElementContract.layoutFrame : VisualElementContract.presentationFrame
        return setValue(feed, on: state, as: .feed)
    }
}
