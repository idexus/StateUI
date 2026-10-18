// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How a value lies on the image: eight little-endian bytes a lane, or text as
/// its length and UTF-8. A lane's bytes are copied as they lie in memory, which
/// is that order on every platform StateUI runs on.
/// Design: docs/design/core/cycle.md#the-image
enum StateImage {
    /// The bytes a value lies as.
    static func bytes(of carried: StateCarried) -> [UInt8] {
        switch carried {
        case .lanes(let lanes):
            return lanes.withUnsafeBytes { Array($0) }

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
        var lane = 0.0
        copy(bytes, from: index * 8, into: &lane)
        return lane
    }

    /// Lays numbers over the lanes starting at `index`.
    static func lay(_ lanes: [Double], at index: Int, into bytes: inout [UInt8]) {
        let start = index * 8
        guard start < bytes.count else { return }

        lanes.withUnsafeBytes { written in
            bytes.withUnsafeMutableBytes { image in
                let count = min(written.count, image.count - start)
                UnsafeMutableRawBufferPointer(rebasing: image[start..<start + count])
                    .copyMemory(from: UnsafeRawBufferPointer(rebasing: written[0..<count]))
            }
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

        var lanes = [Double](repeating: 0, count: count)
        lanes.withUnsafeMutableBufferPointer { lanes in
            copy(bytes, from: 0, into: UnsafeMutableRawBufferPointer(lanes))
        }
        return .lanes(lanes)
    }

    /// Copies as many of `bytes` from `start` as `target` holds and there are, leaving the rest of it as it was.
    private static func copy(_ bytes: [UInt8], from start: Int, into target: UnsafeMutableRawBufferPointer) {
        guard start < bytes.count else { return }

        bytes.withUnsafeBytes { image in
            let count = min(target.count, image.count - start)
            UnsafeMutableRawBufferPointer(rebasing: target[0..<count])
                .copyMemory(from: UnsafeRawBufferPointer(rebasing: image[start..<start + count]))
        }
    }

    /// The same, into one lane.
    private static func copy(_ bytes: [UInt8], from start: Int, into lane: inout Double) {
        withUnsafeMutableBytes(of: &lane) { copy(bytes, from: start, into: $0) }
    }
}

// The image's lanes are copied as they lie in memory: a platform laying a number's
// bytes highest first would need them turned round.
#if !_endian(little)
#error("StateImage copies a lane's bytes as they lie in memory, which it reads as little-endian.")
#endif
