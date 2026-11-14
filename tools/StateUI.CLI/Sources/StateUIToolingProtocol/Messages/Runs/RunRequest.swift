// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An application built, then started and followed until it ends: `application/run`'s parameters.
public struct RunRequest: Codable, Equatable, Sendable {
    /// The build it runs.
    public var build: BuildRequest
    /// Whether it starts held until a debugger attaches.
    public var debugger: Bool

    /// A run of what `build` makes, held for a debugger where `debugger`.
    public init(build: BuildRequest, debugger: Bool = false) {
        self.build = build
        self.debugger = debugger
    }
}
