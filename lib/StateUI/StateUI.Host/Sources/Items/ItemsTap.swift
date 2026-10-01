// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a tap on an item does where the toolkit's collection decides nothing of it: it chooses the item - adding it
/// to a choice of many or taking it away - and opens it, unless it changes a choice of many.
/// Design: docs/design/host/items.md#a-tap
@_spi(Host) public struct ItemsTap: Equatable, Sendable {
    /// The items chosen after the tap; nil where the choice stays as it was.
    public let chosen: [String]?

    /// Whether the tap opens the item.
    public let opens: Bool

    /// A tap on the item of `identity` in a list choosing as `mode` says, `chosen` chosen before it.
    public init(on identity: String, mode: SelectionMode, chosen: [String]) {
        switch mode {
        case .none:
            self.chosen = nil
            opens = true
        case .single:
            self.chosen = [identity]
            opens = true
        case .multiple:
            self.chosen = chosen.contains(identity) ? chosen.filter { $0 != identity } : chosen + [identity]
            opens = false
        }
    }
}
