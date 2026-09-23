// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The batch state values cross a host's boundary in, both ways: `[count: U16]`,
/// then per write `[number: I32][mask: U64][length: U32][bytes]`.
/// Design: docs/design/core/cycle.md#the-state-batch
enum StateBatch {
    /// One state's write: which state, which lanes, and the value whole.
    struct Write: Equatable {
        /// The state's number.
        let number: Int32

        /// Which of its lanes moved.
        let mask: UInt64

        /// The value, whole.
        let bytes: [UInt8]
    }

    /// The bytes a batch lies as.
    static func encode(_ writes: [Write]) -> [UInt8] {
        var bytes: [UInt8] = []

        bytes.reserveCapacity(writes.reduce(2) { $0 + 16 + $1.bytes.count })
        append(UInt64(writes.count), 2, to: &bytes)

        for write in writes {
            append(UInt64(UInt32(bitPattern: write.number)), 4, to: &bytes)
            append(write.mask & 0xFFFF_FFFF, 4, to: &bytes)
            append(write.mask >> 32, 4, to: &bytes)
            append(UInt64(write.bytes.count), 4, to: &bytes)
            bytes += write.bytes
        }

        return bytes
    }

    /// What a batch says as far as its bytes go: the writes read, and whether the
    /// bytes held the whole batch.
    static func decode(_ batch: UnsafeBufferPointer<UInt8>) -> (writes: [Write], complete: Bool) {
        var at = 0

        func take(_ bytes: Int) -> Int? {
            guard at + bytes <= batch.count else { return nil }

            var value = 0

            for byte in 0..<bytes {
                value |= Int(batch[at + byte]) << (byte * 8)
            }

            at += bytes
            return value
        }

        guard let count = take(2) else { return ([], false) }

        var writes: [Write] = []

        for _ in 0..<count {
            guard let number = take(4), let low = take(4), let high = take(4),
                  let length = take(4), at + length <= batch.count
            else { return (writes, false) }

            writes.append(Write(
                number: Int32(truncatingIfNeeded: number),
                mask: UInt64(low) | (UInt64(high) << 32),
                bytes: Array(batch[at..<(at + length)])))
            at += length
        }

        return (writes, true)
    }

    /// What a batch says, from bytes held as an array.
    static func decode(_ bytes: [UInt8]) -> (writes: [Write], complete: Bool) {
        bytes.withUnsafeBufferPointer { decode($0) }
    }

    /// Writes a number little-endian, the width the layout says.
    private static func append(_ value: UInt64, _ width: Int, to bytes: inout [UInt8]) {
        for byte in 0..<width {
            bytes.append(UInt8(truncatingIfNeeded: value >> UInt64(byte * 8)))
        }
    }
}
