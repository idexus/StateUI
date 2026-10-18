// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Synchronization

/// The number a key's name stands for in this process: what a key is hashed and compared by.
/// Design: docs/design/core/contracts.md#a-key-is-a-number
enum NameNumber {
    private static let numbers = Mutex<[String: Int32]>([:])

    /// The number `name` stands for, given at its first asking.
    static func of(_ name: String) -> Int32 {
        numbers.withLock { numbers in
            if let number = numbers[name] { return number }
            let number = Int32(numbers.count)
            numbers[name] = number
            return number
        }
    }
}
