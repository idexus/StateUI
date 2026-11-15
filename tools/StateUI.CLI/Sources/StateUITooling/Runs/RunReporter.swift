// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIToolingProtocol

/// What a run says while it works: its build's words and lines, the application it started, and each line the
/// application writes.
public struct RunReporter: Sendable {
    public var build: BuildReporter
    public var started: @Sendable (LaunchedApplication) -> Void
    public var output: @Sendable (ProcessOutput) -> Void

    /// A reporter telling `build`, `started` and `output`.
    public init(
        build: BuildReporter = BuildReporter(), started: @escaping @Sendable (LaunchedApplication) -> Void = { _ in },
        output: @escaping @Sendable (ProcessOutput) -> Void = { _ in }
    ) {
        self.build = build
        self.started = started
        self.output = output
    }
}
