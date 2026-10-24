// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A menu's entry, or a bar's item, the user chose: carried alike on every host.
/// Design: docs/design/host/pages.md#a-checked-entry
@_spi(Host) extension MountedElement {
    /// The way choosing this entry turns it - a setting's entry, the other way from how it stands checked; nil for an
    /// entry that acts, which choosing clicks.
    public var turnsWhenChosen: Bool? {
        guard type == .menuToggle else { return nil }
        return value(.isOn)?.bool != true
    }

    /// The user chose this entry: a setting's turns the other way - onto its state, then its `toggled` - and one that
    /// acts is clicked.
    public func chosen(in runtime: HostRuntime) {
        // One choice of the user's: what it moves renders together.
        runtime.performUserTransaction {
            if let turned = turnsWhenChosen {
                reportUserChange(.isOn, .toggled, .bool(turned), in: runtime)
            } else {
                send(.clicked, [], in: runtime)
            }
        }
    }
}
