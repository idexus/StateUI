// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How a value lies on the image: eight little-endian bytes a lane, or text as
/// its length and UTF-8.
/// Design: docs/design/core/cycle.md#the-image
enum StateImage {
    /// The bytes a value lies as.
    static func bytes(of carried: StateCarried) -> [UInt8] {
        switch carried {
        case .lanes(let lanes):
            var bytes: [UInt8] = []
            bytes.reserveCapacity(lanes.count * 8)

            for lane in lanes {
                let pattern = lane.bitPattern

                for shift in stride(from: 0, to: 64, by: 8) {
                    bytes.append(UInt8(truncatingIfNeeded: pattern >> UInt64(shift)))
                }
            }

            return bytes

        case .text(let text):
            let utf8 = Array(text.utf8)
            var bytes: [UInt8] = []
            bytes.reserveCapacity(utf8.count + 4)

            for shift in stride(from: 0, to: 32, by: 8) {
                bytes.append(UInt8(truncatingIfNeeded: UInt32(utf8.count) >> UInt32(shift)))
            }

            return bytes + utf8
        }
    }

    /// One lane of an image, by its index. Nought where the bytes stop short.
    static func lane(_ index: Int, of bytes: [UInt8]) -> Double {
        var pattern: UInt64 = 0

        for byte in 0..<8 where index * 8 + byte < bytes.count {
            pattern |= UInt64(bytes[index * 8 + byte]) << UInt64(byte * 8)
        }

        return Double(bitPattern: pattern)
    }

    /// Lays numbers over the lanes starting at `index`.
    static func lay(_ lanes: [Double], at index: Int, into bytes: inout [UInt8]) {
        let written = StateImage.bytes(of: .lanes(lanes))

        for byte in 0..<written.count where index * 8 + byte < bytes.count {
            bytes[index * 8 + byte] = written[byte]
        }
    }

    /// What those bytes stand for, as `count` lanes or, where that is nought, text.
    static func carried(of bytes: [UInt8], lanes count: Int) -> StateCarried {
        // Its own width: as many lanes as there are eight-byte numbers.
        let count = count < 0 ? bytes.count / 8 : count

        guard count > 0 else {
            guard bytes.count >= 4 else { return .text("") }

            var length = 0

            for shift in stride(from: 0, to: 32, by: 8) {
                length |= Int(bytes[shift / 8]) << shift
            }

            let end = min(4 + length, bytes.count)

            return .text(String(decoding: bytes[4..<end], as: UTF8.self))
        }

        var lanes: [Double] = []
        lanes.reserveCapacity(count)

        for lane in 0..<count {
            var pattern: UInt64 = 0

            for byte in 0..<8 where lane * 8 + byte < bytes.count {
                pattern |= UInt64(bytes[lane * 8 + byte]) << UInt64(byte * 8)
            }

            lanes.append(Double(bitPattern: pattern))
        }

        return .lanes(lanes)
    }
}
