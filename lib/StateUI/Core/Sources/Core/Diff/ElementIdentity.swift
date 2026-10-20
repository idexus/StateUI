// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Who an element is as its author wrote it: the value, compared as that value, its hash worked out once as it is
/// written - so siblings are looked up by a number, and two values compared only where their numbers meet.
/// Design: docs/design/core/identity-and-diffing.md#keys
struct ElementIdentity: Hashable {
    let value: AnyHashable
    let number: Int

    init(_ value: AnyHashable) {
        self.value = value
        number = value.hashValue
    }

    static func == (lhs: ElementIdentity, rhs: ElementIdentity) -> Bool {
        lhs.number == rhs.number && lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }
}
