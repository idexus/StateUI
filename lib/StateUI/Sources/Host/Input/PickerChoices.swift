// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A picker's choices and its choice as the tree writes them, the same on every host: the choice is written only
/// where the tree changed it or the choices, so the user's own choice is never argued with.
/// Design: docs/design/host/runtime.md#typed-words
@_spi(Host) public struct PickerChoices: Sendable {
    /// The choices last written.
    public private(set) var choices: [String] = []

    /// A picker holding no choices.
    public init() {}

    /// What `choices` with `chosen` - the tree's choice, `choiceChanged` where the tree changed it - ask of the
    /// picker: the choices where they changed, and whether the choice is written, and which: its place, or nil for
    /// none where no choice stands there.
    public mutating func write(
        _ choices: [String], chosen: Int, choiceChanged: Bool
    ) -> (choices: [String]?, writesChoice: Bool, chosen: Int?) {
        let changed = choices != self.choices
        if changed { self.choices = choices }
        return (changed ? choices : nil, changed || choiceChanged, choices.indices.contains(chosen) ? chosen : nil)
    }
}
