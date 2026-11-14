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

    /// `build` started as `process`, `held` for a debugger or not.
    public init(build: BuildResult, process: Int?, held: Bool) {
        self.build = build
        self.process = process
        self.held = held
    }
}
