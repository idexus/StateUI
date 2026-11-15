// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import StateUIToolingProtocol

/// The options every command writing a result takes.
struct OutputOptions: ParsableArguments {
    @Option(help: "How the result is written: text, json or jsonl.")
    var format: OutputFormat = .text

    /// Writes what `work` answers, or the tooling error it fails with and the status that error ends with.
    func answer<Result: Codable & Sendable>(
        _ work: () async throws -> Result, text: (Result) -> String
    ) async throws {
        let result: Result
        do {
            result = try await work()
        } catch let error as ToolingError {
            try format.write(error)
            throw ExitCode(ExitStatus.of(error))
        }
        try format.write(result, text: text)
    }
}
