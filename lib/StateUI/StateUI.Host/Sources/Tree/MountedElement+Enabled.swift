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

    /// `property` as the element's view presents it: its own value - but `isEnabled` false in a disabled branch,
    /// `isRefreshEnabled` true where the element hears the pull and says nothing of it and false where it is
    /// disabled, and `ignoresInput` true while it fades out.
    public func presented(_ property: Prop) -> HostValue? {
        switch property {
        case .isEnabled where parent?.isEffectivelyEnabled == false: .bool(false)
        case .isRefreshEnabled: isEffectivelyEnabled ? offeredRefresh : offeredRefresh.map { _ in .bool(false) }
        case .ignoresInput where isLeaving: .bool(true)
        default: value(property)
        }
    }

    /// The branch's enablement turned: every element in it presents again what follows its enablement.
    func enablementTurned() {
        for child in children + slots {
            child.native.applied(changed: child.followingEnablement, wasDescribed: true)
            child.enablementTurned()
        }
    }

    /// What the element presents as its enablement turns: its `isEnabled`, and the pull it offers - none while it
    /// is disabled.
    var followingEnablement: Set<Prop> {
        offeredRefresh == nil ? [.isEnabled] : [.isEnabled, .isRefreshEnabled]
    }
}
