// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a host holds by number until it is taken out or let go - a toolkit's callback, an answer a dialog hands
/// back: what crosses C, Java or JavaScript by its number where an object cannot. The numbers are the process's one
/// count, so a number is never given twice.
/// Design: docs/design/host/tree.md#held-by-number
@_spi(Host) @MainActor public final class Numbered<Value> {
    private var held: [Int64: Value] = [:]

    /// Nothing held yet.
    public init() {}

    /// The next number, for a value held once it can be made.
    public func reserve() -> Int64 {
        HostNumbers.next()
    }

    /// Holds `value` under the next number, and answers that number.
    public func hold(_ value: Value) -> Int64 {
        let number = reserve()
        held[number] = value
        return number
    }

    /// Holds `value` under `number`.
    public func hold(_ value: Value, as number: Int64) {
        held[number] = value
    }

    /// What is held under `number`; nil where nothing is.
    public func find(_ number: Int64) -> Value? {
        held[number]
    }

    /// Takes out what is held under `number` - an answer comes once; nil where nothing is held.
    public func take(_ number: Int64) -> Value? {
        held.removeValue(forKey: number)
    }

    /// Lets go of what is held under `number`.
    public func release(_ number: Int64) {
        held[number] = nil
    }

    /// How many are held.
    public var count: Int { held.count }

    /// The numbers held, in the order they were given.
    public var numbers: [Int64] { held.keys.sorted() }
}
