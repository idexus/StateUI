// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A step of a repository suite run with SwiftPM: whether it passed - and, asked with a filter, whether it ran any
/// test at all, since a run of none proves nothing and records nothing.
enum TestRun {
    /// Runs `swift` with `arguments`, its output said through `reporter`.
    static func swift(
        _ swift: ProcessExecutable, _ arguments: [String], _ environment: ProcessEnvironment, _ reporter: BuildReporter
    ) async throws -> Bool {
        let said = Gathered()
        let outcome = try await ProcessRunner().run(
            ProcessRequest(swift, arguments: arguments, environment: environment),
            output: { line in
                said.add(line)
                reporter.output(line)
            })
        try Task.checkCancellation()
        guard outcome.succeeded else { return false }
        if arguments.first == "test", arguments.contains("--filter"),
           !ranAny(said.lines(of: .standardOutput) + said.lines(of: .standardError)) {
            reporter.output(ProcessOutput(stream: .standardError, text: "No test matched the filter: a run of none proves nothing."))
            return false
        }
        return true
    }

    /// Whether `lines` - what `swift test` said - tell of a test run: XCTest's count, or a parallel run's progress.
    static func ranAny(_ lines: [String]) -> Bool {
        lines.contains { $0.contains(#/Executed [1-9][0-9]* tests?/#) || $0.contains(#/^\[[0-9]+/[0-9]+\] Testing /#) }
    }
}
