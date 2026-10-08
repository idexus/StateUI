// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// What the compiler said about each of several files checked at once, written from their lanes.
final class CompilerOutputs: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String?]

    /// Room for `count` answers, each nil until one is set.
    init(count: Int) {
        items = Array(repeating: nil, count: count)
    }

    /// What the compiler said of file `index`; nil where it compiled.
    func set(_ index: Int, _ output: String?) {
        lock.lock()
        defer { lock.unlock() }
        items[index] = output
    }

    /// What the compiler said of file `index`.
    func value(_ index: Int) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return items[index]
    }
}
