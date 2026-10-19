// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The numbers keys hold, each with its name: what refuses a second name of one number.
/// Design: docs/design/core/contracts.md#a-key-is-a-number
struct KeyNumbers {
    private var names: [UInt64: String] = [:]

    /// A name's number: the 64-bit FNV-1a hash of its UTF-8 bytes, the same wherever it is worked out.
    static func number(of name: String) -> UInt64 {
        var number: UInt64 = 0xcbf2_9ce4_8422_2325

        for byte in name.utf8 {
            number ^= UInt64(byte)
            number &*= 0x0000_0100_0000_01b3
        }

        return number
    }

    /// Takes `number` for `name`: nil where it is free or `name`'s already, else the name holding it.
    mutating func take(_ number: UInt64, for name: String) -> String? {
        if let holder = names[number] { return holder == name ? nil : holder }

        names[number] = name
        return nil
    }
}
