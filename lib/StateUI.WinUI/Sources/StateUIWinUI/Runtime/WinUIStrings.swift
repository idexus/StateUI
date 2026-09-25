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
}
