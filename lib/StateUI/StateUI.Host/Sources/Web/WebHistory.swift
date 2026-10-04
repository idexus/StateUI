// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Whether there is a page behind and a page ahead, as a web view last said it: a way is said only as it changes.
/// Design: docs/design/host/web.md#the-way-back-and-forward
@_spi(Host) public struct WebHistory {
    /// The ways as last said.
    public private(set) var back = false
    public private(set) var forward = false

    /// No way back or forward, as a web view stands before its first page.
    public init() {}

    /// Takes the ways as they stand; answers each that changed - nil for one that did not - the way back first to be
    /// said.
    public mutating func changes(back: Bool, forward: Bool) -> (back: Bool?, forward: Bool?) {
        defer { (self.back, self.forward) = (back, forward) }
        return (back != self.back ? back : nil, forward != self.forward ? forward : nil)
    }
}
