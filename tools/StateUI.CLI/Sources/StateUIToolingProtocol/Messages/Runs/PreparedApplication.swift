// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An application readied for a debugger to start on this machine - `application/prepare`'s result: its build, and
/// how the debugger starts it.
public struct PreparedApplication: Codable, Equatable, Sendable {
    public var build: BuildResult
    public var debugger: DebugDescriptor

    /// `build`, started as `debugger` says.
    public init(build: BuildResult, debugger: DebugDescriptor) {
        self.build = build
        self.debugger = debugger
    }
}
