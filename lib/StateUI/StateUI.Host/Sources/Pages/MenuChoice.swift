// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A menu's entry, or a bar's item, the user chose: carried alike on every host.
/// Design: docs/design/host/pages.md#a-checked-entry
@_spi(Host) extension MountedElement {
    /// The way choosing this entry turns it - the other way from how it stands checked; nil for an entry standing
    /// neither way, which choosing only clicks.
    public var turnsWhenChosen: Bool? {
        guard type == .menuItem, let on = value(.isOn)?.bool else { return nil }
        return !on
    }

    /// The user chose this entry: one standing checked or not turns the other way first - onto its state, then its
    /// `toggled` - and then it is clicked.
    public func chosen(in runtime: HostRuntime) {
        // One choice of the user's: the turn and the click render together.
        runtime.performUserTransaction {
            if let turned = turnsWhenChosen {
                reportUserChange(.isOn, .toggled, .bool(turned), in: runtime) { _ in }
            }
            send(.clicked, [], in: runtime)
        }
    }
}
