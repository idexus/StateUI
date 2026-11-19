// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An application a run started: its build and its process - the `started` event of `application/run`, which a
/// debugger attaches by.
public struct LaunchedApplication: Codable, Equatable, Sendable {
    /// The build it runs: its bundle, its program and, for a UIKit head, its device or simulator.
    public var build: BuildResult
    /// Its process: on a simulator one of this machine's, on a device the device's; `nil` where the platform does
    /// not say it.
    public var process: Int?
    /// Whether it waits, stopped, for a debugger to attach.
    public var held: Bool
    /// How a debugger reaches it, where the run readied one.
    public var debugger: DebugDescriptor?
    /// A Web head's page, where it is served: `http://127.0.0.1:8460/`.
    public var url: String?

    /// `build` started as `process`, `held` for a debugger or not, a debugger reaching it as `debugger` says, a page
    /// served at `url`.
    public init(build: BuildResult, process: Int?, held: Bool, debugger: DebugDescriptor? = nil, url: String? = nil) {
        self.build = build
        self.process = process
        self.held = held
        self.debugger = debugger
        self.url = url
    }
}
