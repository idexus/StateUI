// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension HostRecord {
    /// What every host records alike of a layout engine: its phase walked by the host layer's channel, which every
    /// host runs; its views standing where its arithmetic says, from its own top left, so no host gives it a padding;
    /// and no style naming it, a layout of some items having no initializer that sets nothing.
    /// Design: docs/design/views/layout-engine.md#the-element
    public static let layoutEngine: [HostRecord] = [
        .complete(LayoutEngineContract.phase),
        .notPlanned(PaddingElementContract.padding, on: LayoutEngineContract.self,
            reason: "A layout engine stands its views where its arithmetic says, from its own top left: it takes no "
                + "padding."),
        .unrealized(VisualElementContract.style, on: LayoutEngineContract.self,
            why: "No style can name a LayoutEngine: a style names its control by an initializer that sets nothing, "
                + "which a layout of some items has not."),
    ]
}
