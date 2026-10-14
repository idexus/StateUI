// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension HostRecord {
    /// What every host records alike of a layout engine: its views stand where its arithmetic says, from its own top
    /// left, so no host gives it a padding; and no style can name it, a layout of some items having no initializer
    /// that sets nothing.
    /// Design: docs/design/views/layout-engine.md#the-element
    public static let layoutEngine: [HostRecord] = [
        .notPlanned(
            "LayoutEngine", "padding",
            reason: "A layout engine stands its views where its arithmetic says, from its own top left: it takes no "
                + "padding."),
        .unrealized(
            "LayoutEngine", "style",
            why: "No style can name a LayoutEngine: a style names its control by an initializer that sets nothing, "
                + "which a layout of some items has not."),
    ]
}
