// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension ToolbarItem {
    /// The button that shows a scene's inspector and hides it again - for a
    /// page's `toolbarItems`. See `Inspector`.
    ///
    ///     @Environment private var scene: SceneSession
    ///     @Environment private var page: PageSession
    ///
    ///     VStack { … }
    ///         .onCreated { page.toolbarItems = [.inspector(scene)] }
    ///
    /// - Parameter scene: the scene whose inspector it shows - the page's own.
    public static func inspector(_ scene: SceneSession) -> ToolbarItem {
        ToolbarItem("ⓘ")
            .id("stateui.inspector")
            .accessibilityIdentifier("stateui.inspector")
            .onClicked { Inspector.toggle(in: scene) }
    }
}
