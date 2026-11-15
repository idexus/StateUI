// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How a run ended: `application/run`'s result, once the application ended by itself.
public struct RunResult: Codable, Equatable, Sendable {
    /// What was started.
    public var launched: LaunchedApplication
    /// The status the application ended with, where the platform says it.
    public var exitStatus: Int?

    /// `launched` ended with `exitStatus`.
    public init(launched: LaunchedApplication, exitStatus: Int?) {
        self.launched = launched
        self.exitStatus = exitStatus
    }
}
