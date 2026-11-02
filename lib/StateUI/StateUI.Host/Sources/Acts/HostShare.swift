// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What the user is offered to share - words, an address, or both - as every host reads the act that offers it.
/// Design: docs/design/host/runtime.md#sharing
@_spi(Host) public struct HostShare: Equatable, Sendable {
    /// The words offered; nil where only an address is.
    public let text: String?

    /// The address offered; nil where only words are.
    public let address: String?

    /// Words and an address to share.
    public init(text: String?, address: String?) {
        self.text = text
        self.address = address
    }

    /// What `call` offers to share; nil for an act that offers nothing.
    public init?(_ call: HostActCall) {
        guard call.act == .share else { return nil }
        let arguments = AskedWindow.arguments(of: call)
        let (text, address) = (arguments.value(0)?.string, arguments.value(1)?.string)
        guard text != nil || address != nil else { return nil }
        self.init(text: text, address: address)
    }

    /// The words and the address as one text, where a platform carries one: the words, then the address on a line
    /// of its own.
    public var together: String {
        [text, address].compactMap { $0 }.joined(separator: "\n")
    }
}
