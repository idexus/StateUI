// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The button that shows its scene's inspector and hides it again, for
/// anywhere a view goes. See `Inspector`; in a bar, `ToolbarItem.inspector`.
///
///     VStack { InspectorButton() }
public struct InspectorButton: View {
    /// The scene the button is in, whose inspector it shows.
    @Environment private var scene: SceneSession

    /// The button.
    public init() {}

    /// The button, as a view.
    public var body: some View {
        Button("ⓘ")
            .fontSize(16)
            .textColor(Look.subtle)
            .background(.transparent)
            .padding(horizontal: 10, vertical: 2)
            .accessibilityIdentifier("stateui.inspector")
            .accessibilityLabel("Inspector")
            .onClicked { Inspector.toggle(in: scene) }
    }
}
