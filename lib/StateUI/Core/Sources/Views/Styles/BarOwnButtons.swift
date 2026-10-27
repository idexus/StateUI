// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The look a bar's own buttons wear where a host draws the bar itself - the way back, a split view's sidebar
/// toggle, More, a sheet's close: each stands as a lone item does, in the box the style every `ToolbarGroup` wears
/// gives it, under the style every `ToolbarButton` wears - in the state the user puts it in. They are no element,
/// so the host asks as the user moves over them, and StateUI orders the states as everywhere.
/// Design: docs/design/views/styles.md#a-bars-own-buttons
@_spi(Host) public enum BarOwnButtons {
    /// The values the two styles say, each with its states that hold laid over its own - the button's over the
    /// group's box - each theme picked.
    @MainActor
    public static func look(pressed: Bool, pointerOver: Bool) -> [Prop: HostValue] {
        let facts = VisualStateRules.Facts(pressed: pressed, pointerOver: pointerOver)
        let box = [BorderElementContract.shape.token, BorderElementContract.stroke.token,
                   BorderElementContract.lineWidth.token, BarItemElementContract.background.token]
        let group = resolved(Node(contract: ToolbarGroupContract.self), facts).filter { box.contains($0.key) }
        return group.merging(resolved(Node(contract: ToolbarButtonContract.self), facts)) { _, button in button }
    }

    /// The values `node` takes from its style in the state `facts` say, each theme picked.
    @MainActor
    private static func resolved(_ node: Node, _ facts: VisualStateRules.Facts) -> [Prop: HostValue] {
        let node = styled(node, with: Renderer.shared.differ.styles)
        let holding = VisualStateRules.holding(node.visualStates, facts: facts)
        return VisualStateRules.resolved(node.props, states: node.visualStates, holding: holding)
            .mapValues { $0.isThemed ? $0.resolvingTheme() : $0 }
    }
}
