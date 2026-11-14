// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIToolingProtocol

/// A program a build or a run takes as a step - `codesign`, `actool`, `simctl` - which must succeed.
enum ToolStep {
    /// Runs `tool` with `arguments`, for at most `limit`.
    ///
    /// - Throws: ``ToolingError`` `TOOL_FAILED` with the last of what it said, where it failed.
    static func run(_ tool: String, _ arguments: [String], limit: Duration = .seconds(120)) async throws {
        let said = Gathered()
        let outcome = try await ProcessRunner().run(ProcessRequest(.name(tool), arguments: arguments, timeout: limit), output: said.add)
        guard outcome.succeeded else {
            let words = (said.lines(of: .standardError) + said.lines(of: .standardOutput)).suffix(5).joined(separator: "\n")
            throw ToolingError(.toolFailed, "\(tool) \(arguments.first ?? "") refused:\n\(words)")
        }
    }

    /// Runs `tool` with `arguments` to its end even where the caller was cancelled: a stop's own step.
    static func regardless(_ tool: String, _ arguments: [String]) async {
        await Task.detached {
            _ = try? await ProcessRunner().run(ProcessRequest(.name(tool), arguments: arguments, timeout: .seconds(30)))
        }.value
    }
}
