// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An inspector docked in its scene's main window, in a layout that takes no
/// touches of its own, so the page under it stays in use.
struct InspectorPanel: ContentView {
    /// The scene it looks at, by its number.
    let scene: String

    /// Where it docks.
    let place: Inspector.Place

    @Environment private var device: DeviceInfo

    var content: any View {
        // Read here, so a panel folding or opening out is the one view built
        // again - the window under it standing as it was.
        let collapsed = place == .bottom && InspectorModel.shared.collapsed.contains(scene)
        let wide = place == .bottom && device.formFactor != .phone && device.formFactor != .unknown

        let panel = Border {
            if collapsed {
                InspectorStrip(scene: scene)
            } else {
                InspectorView(scene: scene, place: place, wide: wide)
            }
        }
        .background(Look.ground)
        .stroke(Look.edge)
        .strokeWidth(1)
        .shape(.roundedRectangle(14))
        .margin(8)

        if place == .side {
            // Under the bar, which keeps the page's own buttons in reach.
            return Grid { panel.gridRow(1).gridColumn(1) }
                .rows(.fixed(Look.bar), .fill)
                .columns(.fill, .fixed(Look.side))
                .letsInputThrough(true)
        }

        if collapsed {
            // One line along the bottom, as tall as what it says.
            return Grid { panel.gridRow(1) }
                .rows(.fill, .auto)
                .letsInputThrough(true)
        }

        return Grid { panel.gridRow(1) }
            .rows(.proportional(wide ? 1.25 : 1), .proportional(1))
            .letsInputThrough(true)
    }
}
