// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A program a build or a run takes as a step - `codesign`, `actool`, `simctl` - which must succeed.
enum ToolStep {
    /// Runs `executable` with `arguments` in `environment`, for at most `limit`, and returns what it printed to its
    /// standard output, a line each.
    ///
    /// - Throws: ``ToolingError`` `TOOL_FAILED` with the last of what it said, where it failed.
    @discardableResult
    static func run(
        _ executable: ProcessExecutable, _ arguments: [String], environment: ProcessEnvironment = .inherited,
        limit: Duration = .seconds(120)
    ) async throws -> String {
        let said = Gathered()
        let request = ProcessRequest(executable, arguments: arguments, environment: environment, timeout: limit)
        let outcome = try await ProcessRunner().run(request, output: said.add)
        guard outcome.succeeded else {
            let words = (said.lines(of: .standardError) + said.lines(of: .standardOutput)).suffix(5).joined(separator: "\n")
            let name = switch executable {
            case .name(let name): name
            case .path(let path): URL(fileURLWithPath: path).lastPathComponent
            }
            // xcrun runs another's program: that one and what it was asked name the step.
            let asked = arguments.prefix(name == "xcrun" ? 2 : 1).joined(separator: " ")
            throw ToolingError(.toolFailed, "\(name) \(asked) refused - \(ending(outcome, limit: limit)):\n\(words)")
        }
        return said.lines(of: .standardOutput).joined(separator: "\n")
    }

    /// How a step that failed ended, in words: a step saying nothing is still told apart.
    static func ending(_ outcome: ProcessOutcome, limit: Duration) -> String {
        switch (outcome.stop, outcome.termination) {
        case (.timeout?, _): "it ran past \(limit)"
        case (.cancellation?, _): "it was cancelled"
        case (nil, .exited(let status)): "it exited with status \(status)"
        case (nil, .signaled(let signal)): "signal \(signal) ended it"
        }
    }

    /// Runs `executable` with `arguments` to its end even where the caller was cancelled: a stop's own step.
    static func regardless(_ executable: ProcessExecutable, _ arguments: [String]) async {
        await Task.detached {
            _ = try? await ProcessRunner().run(ProcessRequest(executable, arguments: arguments, timeout: .seconds(30)))
        }.value
    }
}
