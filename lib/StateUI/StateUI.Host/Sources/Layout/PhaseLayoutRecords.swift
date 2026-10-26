// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension HostRecord {
    /// What every host records alike of a phase layout: its phase walked by the host layer's channel, which every
    /// host runs; its views standing where its arithmetic says, from its own top left, so no host gives it a padding;
    /// and no style naming it, a layout of some items having no initializer that sets nothing.
    /// Design: docs/design/views/phase-layout.md#the-element
    public static let phaseLayout: [HostRecord] = [
        .complete(PhaseLayoutContract.phase),
        .notPlanned(PaddingElementContract.padding, on: PhaseLayoutContract.self,
            reason: "A phase layout stands its views where its arithmetic says, from its own top left: it takes no "
                + "padding."),
        .unrealized(VisualElementContract.style, on: PhaseLayoutContract.self,
            why: "No style can name a PhaseLayout: a style names its control by an initializer that sets nothing, "
                + "which a layout of some items has not."),
    ]
}
