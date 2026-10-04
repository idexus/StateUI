// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The button that shows its scene's inspector docked in its window and hides
/// it again, for anywhere a view goes. See `Inspector`; in a bar,
/// `ToolbarItem.inspector`.
///
///     VStack { InspectorButton() }
public struct InspectorButton: View {
    /// The window the button is in, where its scene's inspector docks.
    @Environment(\.window) private var window

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
            .onClicked { Inspector.toggle(in: window) }
    }
}
