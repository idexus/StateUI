// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The properties every layout has, shared by the control and its `Style`.
public protocol LayoutProperties: ViewProperties {}

/// A view that arranges children.
public protocol Layout: ElementView, LayoutProperties, PaddingElement, BorderElement, KeyboardElement {}

extension LayoutProperties {
    /// Whether a child drawn outside the layout's bounds is cut off at them.
    public func clipsContent(_ value: Bool) -> Modified {
        setValue(LayoutContract.clipsContent, value)
    }

    /// Whether the layout's own empty area lets input through to whatever is
    /// behind it, while its children still answer - an overlay whose buttons
    /// float over a page that stays in reach.
    ///
    ///     Grid { panel }.letsInputThrough(true)
    ///
    /// `.ignoresInput(true)` is the other half: the view and everything in it
    /// let input through. Where both are set, `ignoresInput` wins.
    public func letsInputThrough(_ value: Bool) -> Modified {
        setValue(LayoutContract.letsInputThrough, value)
    }

    /// The edges on which this layout runs under what stands over its page -
    /// the bars, a notch, the home indicator, the on-screen keyboard; on the
    /// others it stands clear of them.
    ///
    ///     VStack { … }.ignoresSafeArea(.all)             // edge to edge
    ///     Grid { … }.ignoresSafeArea([.start, .top])
    ///
    /// A page's own layout is the one that runs under them; a layout deeper in
    /// stands where its page puts it, and a page with nothing over it changes
    /// nothing. A scroller filling a page that runs under the bars keeps its
    /// first and last content clear of them. A header meant to reach the top
    /// edge wants `.top`: its content then sits where its padding says.
    public func ignoresSafeArea(_ edges: SafeAreaEdges) -> Modified {
        setValue(LayoutContract.ignoresSafeArea, edges)
    }
}

extension Layout {
    /// `letsInputThrough` from a state, `$x`: the host sets each new value as
    /// it stands, and no view is rebuilt for it.
    public func letsInputThrough(_ state: Binding<Bool>) -> Modified {
        twin(LayoutContract.letsInputThrough, by: state)
    }

    /// `clipsContent` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func clipsContent(_ state: Binding<Bool>) -> Modified {
        twin(LayoutContract.clipsContent, by: state)
    }

    /// `ignoresSafeArea` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func ignoresSafeArea(_ state: Binding<SafeAreaEdges>) -> Modified {
        twin(LayoutContract.ignoresSafeArea, carrying: state)
    }
}
