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

    /// Words the relay writes into a buffer the caller hands it, answering how long they are: asked once for the
    /// length, then written.
    static func read(_ fill: (UnsafeMutablePointer<CChar>?, Int32) -> Int32) -> String {
        let length = Int(fill(nil, 0))
        var bytes = [CChar](repeating: 0, count: length + 1)
        _ = bytes.withUnsafeMutableBufferPointer { fill($0.baseAddress, Int32($0.count)) }
        return String(decoding: bytes.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
