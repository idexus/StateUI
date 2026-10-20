// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A path worked as one number: the 64-bit FNV-1a hash of its steps, each after a byte no UTF-8 text holds - the
/// same in every process, so two walks of one tree give equal paths, and none is spelled to be compared.
/// Design: docs/design/core/identity-and-diffing.md#a-path-is-a-number
struct PathNumber: Hashable, Sendable {
    private(set) var number: UInt64 = 0xcbf2_9ce4_8422_2325

    /// The path a step on, the step a name.
    func appending(_ step: String) -> PathNumber {
        var next = self
        next.mix(0xFF)
        for byte in step.utf8 { next.mix(byte) }
        return next
    }

    /// The path a step on, the step a number.
    func appending(_ step: UInt64) -> PathNumber {
        var next = self
        next.mix(0xFE)
        for shift in stride(from: 0, to: 64, by: 8) { next.mix(UInt8(truncatingIfNeeded: step >> UInt64(shift))) }
        return next
    }

    private mutating func mix(_ byte: UInt8) {
        number ^= UInt64(byte)
        number &*= 0x0000_0100_0000_01b3
    }
}
