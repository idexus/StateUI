// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The button that shows its scene's inspector and hides it again, for
/// anywhere a view goes - a window's title bar, or a page of its own. See
/// `Inspector`.
///
///     TitleBar().trailingContent { InspectorButton() }
public struct InspectorButton: ContentView {
    /// The scene the button is in, whose inspector it shows.
    @Environment private var scene: SceneSession

    /// The button.
    public init() {}

    /// The button, as a view.
    public var content: any View {
        Button("ⓘ")
            .fontSize(16)
            .textColor(Look.subtle)
            .background(.transparent)
            .padding(10, 2)
            .accessibilityIdentifier("stateui.inspector")
            .accessibilityLabel("Inspector")
            .onClicked { Inspector.toggle(in: scene) }
    }
}
