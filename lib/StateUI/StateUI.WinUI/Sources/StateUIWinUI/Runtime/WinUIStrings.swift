// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ucrt

/// Words handed to the relay as C strings.
enum WinUIStrings {
    /// Runs `body` with `strings` as C strings, held for the call and freed in Swift.
    static func withCStrings<Result>(_ strings: [String], _ body: ([UnsafePointer<CChar>?]) -> Result) -> Result {
        let copies = strings.map { _strdup($0) }
        defer { copies.forEach { free($0) } }
        return body(copies.map { $0.map { UnsafePointer($0) } })
    }

    /// A list as the relay takes it in one string: each entry ended by a line feed.
    static func lines(_ entries: [String]) -> String {
        entries.map { $0 + "\n" }.joined()
    }

    /// Words the relay writes into a buffer the caller hands it, answering how long they are: written into room
    /// enough, and again into more where they grew past it meanwhile, never cut.
    static func read(_ fill: (UnsafeMutablePointer<CChar>?, Int32) -> Int32) -> String {
        var room = 256
        while true {
            var bytes = [CChar](repeating: 0, count: room)
            let length = Int(bytes.withUnsafeMutableBufferPointer { fill($0.baseAddress, Int32($0.count)) })
            guard length >= room else {
                return String(decoding: bytes.prefix(max(length, 0)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
            }
            room = length + 1
        }
    }
}
