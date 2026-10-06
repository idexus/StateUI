// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A view the tree disables takes no input, and neither does anything standing in it - the same on every host.
/// Design: docs/design/host/runtime.md#a-disabled-branch
extension MountedElement {
    /// Whether the user's hand reaches the element: neither it nor any element holding it says `isEnabled(false)`.
    public var isEffectivelyEnabled: Bool {
        value(.isEnabled)?.bool != false && parent?.isEffectivelyEnabled != false
    }

    /// `property` as the element's view presents it: its own value - but `isEnabled` false in a disabled branch.
    public func presented(_ property: Prop) -> HostValue? {
        property == .isEnabled && parent?.isEffectivelyEnabled == false ? .bool(false) : value(property)
    }

    /// The branch's enablement turned: every element in it presents its `isEnabled` again.
    func enablementTurned() {
        for child in children + slots {
            child.native.applied(changed: [.isEnabled], wasDescribed: true)
            child.enablementTurned()
        }
    }
}
