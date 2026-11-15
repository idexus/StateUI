// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIToolingProtocol

/// Design: docs/design/tooling/command-line.md#exit-status
enum ExitStatus {
    static let toolFailed: Int32 = 1
    static let invalidCommand: Int32 = 2
    static let missingPrerequisite: Int32 = 3
    static let incompatible: Int32 = 4
    static let conflict: Int32 = 5
    static let lostClient: Int32 = 6
    static let interrupted: Int32 = 130

    /// The status a command refused or failed by `error` ends with.
    static func of(_ error: ToolingError) -> Int32 {
        switch error.code {
        case .projectNotFound, .notFound, .invalidName, .invalidConfiguration: invalidCommand
        case .alreadyExists: conflict
        case .incompatibleLibrary: incompatible
        case .missingToolchain: missingPrerequisite
        case .toolFailed: toolFailed
        default: lostClient
        }
    }
}
