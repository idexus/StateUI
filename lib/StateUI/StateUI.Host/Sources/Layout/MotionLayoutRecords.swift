// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension HostRecord {
    /// What every host records alike of a motion layout: its parameters walked by the host layer's channel, which every
    /// host runs; and its views standing where its arithmetic says, from its own top left, so no host gives it a
    /// padding.
    /// Design: docs/design/views/motion-layout.md#the-element
    public static let motionLayout: [HostRecord] = [
        .complete(MotionLayoutContract.parameters),
        .complete(MotionLayoutContract.mirrorsRightToLeft),
        .notPlanned(PaddingElementContract.padding, on: MotionLayoutContract.self,
            reason: "A motion layout stands its views where its arithmetic says, from its own top left: it takes no "
                + "padding."),
    ]
}
