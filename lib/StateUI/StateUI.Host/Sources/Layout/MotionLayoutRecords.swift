// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension HostRecord {
    /// What every host records alike of a motion layout: its parameters walked by the host layer's channel, which every
    /// host runs; and its views standing where its arithmetic says, from its own top left, so no host gives it a
    /// padding. What the hand moves of it each host records itself, by what its toolkit tells of the hand.
    /// Design: docs/design/views/motion-layout.md#the-element
    public static let motionLayout: [HostRecord] = [
        .complete(MotionLayoutContract.parameters),
        .complete(MotionLayoutContract.layout),
        .complete(MotionLayoutContract.mirrorsRightToLeft),
        .notPlanned(PaddingElementContract.padding, on: MotionLayoutContract.self,
            reason: "A motion layout stands its views where its arithmetic says, from its own top left: it takes no "
                + "padding."),
    ]

    /// What every host records alike of a layout's bodies: the host layer places every layout's children, and
    /// brings each onto its place as its body says.
    /// Design: docs/design/host/motion.md#a-child-that-is-a-body
    public static let layoutBodies: [HostRecord] = [
        .complete(LayoutContract.layoutBodies),
    ]
}
