// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One act the application called, for a native host to perform.
///
/// The application calls through `stateUICall` or `stateUISend`. The host
/// takes the call with `HostBoundary.takeActCalls()` and answers one that
/// carries a completion with `HostBoundary.reply(_:with:)` or
/// `HostBoundary.fail(_:reason:)`.
@_spi(Host) public struct HostActCall: Sendable {
    /// The act's token.
    public let act: Act

    /// Typed arguments, in the order the act declares them.
    public let arguments: [HostValue]

    /// The negative id the answer quotes back, or nil when nobody waits.
    public let completion: Int?
}

extension HostActCall {
    init(_ call: ActCall) {
        act = call.act
        arguments = call.arguments
        completion = call.completion
    }
}
