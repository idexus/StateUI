// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The page of an inspector's own window.
struct InspectorPage: View {
    /// The scene it looks at, by its number.
    let scene: String

    /// The window it is the page of.
    @Environment(\.window) private var window

    var body: some View {
        InspectorView(scene: scene, place: .window, wide: true)
            .pageBackground(Look.ground)
            .onCreated {
                window.title = "Inspector"
                window.width = 900           // the renders and the one chosen, side by side
                window.height = 760          // a tree of some depth
                window.minimumWidth = 560    // below this the two halves no longer read
                window.minimumHeight = 420   // below this the tree has no room

                // One more place the inspector shows.
                InspectorModel.shared.windows += 1
                InspectorModel.shared.record()
            }
            .onDestroying {
                // Recording stops once nothing shows.
                InspectorModel.shared.windows -= 1
                InspectorModel.shared.settle()
            }
    }
}
