// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The append helpers every record is written with - little-endian, fixed width.
extension [UInt8] {
    mutating func u8(_ value: UInt8) {
        append(value)
    }

    mutating func u16(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
    }

    mutating func u32(_ value: UInt32) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value >> 16))
        append(UInt8(truncatingIfNeeded: value >> 24))
    }

    /// Eight bytes, little-endian - what a shape crosses as.
    mutating func u64(_ value: UInt64) {
        for shift in stride(from: 0, to: 64, by: 8) {
            append(UInt8(truncatingIfNeeded: value >> UInt64(shift)))
        }
    }

    mutating func i32(_ value: Int32) {
        u32(UInt32(bitPattern: value))
    }

    mutating func f64(_ value: Double) {
        var bits = value.bitPattern
        for _ in 0..<8 {
            append(UInt8(truncatingIfNeeded: bits))
            bits >>= 8
        }
    }

    /// A length-prefixed UTF-8 string - nothing escaped, nothing scanned.
    mutating func string(_ value: String) {
        let bytes = Array(value.utf8)
        u32(UInt32(bytes.count))
        append(contentsOf: bytes)
    }

    /// One tagged value. A name is not written here: its number belongs to a session's
    /// dictionary, so it goes through `Wire.write(_:into:dictionary:)`.
    mutating func value(_ value: PropValue) {
        switch value {
        case .bool(false):
            u8(1)
        case .bool(true):
            u8(2)
        case .number(let number):
            u8(3)
            f64(number)
        case .string(let text):
            u8(4)
            string(text)
        case .numbers(let numbers):
            u8(5)
            u16(Wire.count(numbers.count, of: "numbers in one value"))
            for number in numbers {
                f64(number)
            }
        case .strings(let strings):
            u8(6)
            u16(Wire.count(strings.count, of: "strings in one value"))
            for text in strings {
                string(text)
            }
        case .color(let red, let green, let blue, let alpha):
            u8(8)
            u8(red)
            u8(green)
            u8(blue)
            u8(alpha)
        case .values(let values):
            u8(9)
            u16(Wire.count(values.count, of: "parts of one value"))
            for value in values {
                self.value(value)
            }
        case .enumeration(let member):
            u8(10)
            i32(member)
        case .nothing:
            u8(12)
        case .themed:
            self.value(value.resolvingTheme())
        case .name(let name):
            preconditionFailure(
                "a name ('\(name)') rides the session dictionary - write it "
                    + "through Wire.encode, not the bare value helper")
        }
    }
}
