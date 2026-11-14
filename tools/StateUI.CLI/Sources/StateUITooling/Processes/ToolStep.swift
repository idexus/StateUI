// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A program a build or a run takes as a step - `codesign`, `actool`, `simctl` - which must succeed.
enum ToolStep {
    /// Runs `executable` with `arguments` in `environment`, for at most `limit`.
    ///
    /// - Throws: ``ToolingError`` `TOOL_FAILED` with the last of what it said, where it failed.
    static func run(
        _ executable: ProcessExecutable, _ arguments: [String], environment: ProcessEnvironment = .inherited,
        limit: Duration = .seconds(120)
    ) async throws {
        let said = Gathered()
        let request = ProcessRequest(executable, arguments: arguments, environment: environment, timeout: limit)
        let outcome = try await ProcessRunner().run(request, output: said.add)
        guard outcome.succeeded else {
            let words = (said.lines(of: .standardError) + said.lines(of: .standardOutput)).suffix(5).joined(separator: "\n")
            let name = switch executable {
            case .name(let name): name
            case .path(let path): URL(fileURLWithPath: path).lastPathComponent
            }
            throw ToolingError(.toolFailed, "\(name) \(arguments.first ?? "") refused:\n\(words)")
        }
    }

    /// Runs `executable` with `arguments` to its end even where the caller was cancelled: a stop's own step.
    static func regardless(_ executable: ProcessExecutable, _ arguments: [String]) async {
        await Task.detached {
            _ = try? await ProcessRunner().run(ProcessRequest(executable, arguments: arguments, timeout: .seconds(30)))
        }.value
    }
}
