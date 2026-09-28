// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One effect of executing the contract, written once: a page, what the user and the program do to it, and what
/// must follow - on every host alike, whatever it looks like there.
/// Design: docs/design/host/conformance.md#a-case
@_spi(Host) public struct ConformanceCase: Sendable {
    /// The case's name, as a test's: what holds.
    public let name: String

    /// The contract's members the case proves: its outcome is their verdict.
    public let proves: [Covered]

    /// What the case uses without proving it - a button whose click makes the change the case is about: the case
    /// runs only on a host realizing it too, and says nothing of it.
    public let needs: [Covered]

    /// The case, through a session on the host it runs on.
    public let body: @MainActor @Sendable (Session) throws -> Void

    /// A case named `name`, proving `proves` with the help of `needs`.
    public init(
        _ name: String, proves: [Covered], needs: [Covered] = [],
        _ body: @escaping @MainActor @Sendable (Session) throws -> Void
    ) {
        self.name = name
        self.proves = proves
        self.needs = needs
        self.body = body
    }
}
