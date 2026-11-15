// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// SHA-256 (FIPS 180-4) in Swift alone, the same on every system: the checksum a distribution's archive is published
/// with.
enum SHA256 {
    private static let rounds: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ]

    /// The digest of `data`, as lowercase hexadecimal.
    static func hex(_ data: Data) -> String {
        var state: [UInt32] = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
        var message = [UInt8](data)
        let length = UInt64(message.count) * 8
        message.append(0x80)
        while message.count % 64 != 56 { message.append(0) }
        message += (0..<8).map { UInt8(truncatingIfNeeded: length >> (56 - 8 * $0)) }
        var words = [UInt32](repeating: 0, count: 64)
        for block in stride(from: 0, to: message.count, by: 64) {
            for index in 0..<16 {
                words[index] = (0..<4).reduce(0) { $0 << 8 | UInt32(message[block + index * 4 + $1]) }
            }
            for index in 16..<64 {
                let low = words[index - 15].rotated(7) ^ words[index - 15].rotated(18) ^ (words[index - 15] >> 3)
                let high = words[index - 2].rotated(17) ^ words[index - 2].rotated(19) ^ (words[index - 2] >> 10)
                words[index] = words[index - 16] &+ low &+ words[index - 7] &+ high
            }
            var (a, b, c, d, e, f, g, h) = (state[0], state[1], state[2], state[3], state[4], state[5], state[6], state[7])
            for index in 0..<64 {
                let first = h &+ (e.rotated(6) ^ e.rotated(11) ^ e.rotated(25)) &+ ((e & f) ^ (~e & g)) &+ rounds[index] &+ words[index]
                let second = (a.rotated(2) ^ a.rotated(13) ^ a.rotated(22)) &+ ((a & b) ^ (a & c) ^ (b & c))
                (h, g, f, e, d, c, b, a) = (g, f, e, d &+ first, c, b, a, first &+ second)
            }
            for (index, value) in [a, b, c, d, e, f, g, h].enumerated() { state[index] &+= value }
        }
        return state.map { String($0, radix: 16).leftPadded(to: 8) }.joined()
    }
}

private extension UInt32 {
    func rotated(_ count: UInt32) -> UInt32 { self >> count | self << (32 - count) }
}

private extension String {
    func leftPadded(to length: Int) -> String { String(repeating: "0", count: max(0, length - count)) + self }
}
