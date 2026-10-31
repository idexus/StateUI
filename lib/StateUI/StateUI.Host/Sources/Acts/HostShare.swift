// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What the user is offered to share - words, a link, or both - as every host reads the act that offers it.
/// Design: docs/design/host/runtime.md#sharing
@_spi(Host) public struct HostShare: Equatable, Sendable {
    /// The words offered; nil where only a link is.
    public let text: String?

    /// The link offered; nil where only words are.
    public let link: String?

    /// Words and a link to share.
    public init(text: String?, link: String?) {
        self.text = text
        self.link = link
    }

    /// What `call` offers to share; nil for an act that offers nothing.
    public init?(_ call: HostActCall) {
        guard call.act == .share else { return nil }
        let arguments = AskedWindow.arguments(of: call)
        let (text, link) = (arguments.value(0)?.string, arguments.value(1)?.string)
        guard text != nil || link != nil else { return nil }
        self.init(text: text, link: link)
    }

    /// The words and the link as one text, where a platform carries one: the words, then the link on a line of its
    /// own.
    public var together: String {
        [text, link].compactMap { $0 }.joined(separator: "\n")
    }
}
