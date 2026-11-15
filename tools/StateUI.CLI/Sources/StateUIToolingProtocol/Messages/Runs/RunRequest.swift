// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An application built, then started and followed until it ends: `application/run`'s parameters.
public struct RunRequest: Codable, Equatable, Sendable {
    /// The build it runs.
    public var build: BuildRequest
    /// Whether it starts held until a debugger attaches.
    public var debugger: Bool
    /// A Web head's: the port its page is served on - 8460, else another free, where none is asked for.
    public var port: Int?
    /// A Web head's: whether its page is shared with the network, not served on this machine alone.
    public var lan: Bool?

    /// A run of what `build` makes, held for a debugger where `debugger`, a page served on `port`, on the network
    /// where `lan`.
    public init(build: BuildRequest, debugger: Bool = false, port: Int? = nil, lan: Bool? = nil) {
        self.build = build
        self.debugger = debugger
        self.port = port
        self.lan = lan
    }
}
