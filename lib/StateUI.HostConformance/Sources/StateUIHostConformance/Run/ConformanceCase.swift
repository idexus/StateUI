// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One effect of executing the contract, written once: a page, what the user and the program do to it, and what
/// must follow - on every host alike, whatever it looks like there.
/// Design: docs/design/host/conformance.md#a-case
@_spi(Host) public struct ConformanceCase: Sendable {
    /// The case's name, as a test's: what holds.
    public let name: String

    /// The contract's members the case covers: it runs only on a host realizing all of them.
    public let covers: [Covered]

    /// The case, through a session on the host it runs on.
    public let body: @MainActor @Sendable (Session) throws -> Void

    /// A case named `name`, covering `covers`.
    public init(_ name: String, covers: [Covered], _ body: @escaping @MainActor @Sendable (Session) throws -> Void) {
        self.name = name
        self.covers = covers
        self.body = body
    }
}
