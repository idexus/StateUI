// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a program prints when a check asks it something.
enum ToolOutput {
    /// What `executable` run with `arguments` printed - both streams, a line each - or `nil` where it did not run or
    /// printed nothing while failing.
    static func text(
        _ executable: ProcessExecutable, _ arguments: [String], environment: ProcessEnvironment = .inherited
    ) async -> String? {
        let output = Gathered()
        let request = ProcessRequest(executable, arguments: arguments, environment: environment, timeout: .seconds(30))
        guard let outcome = try? await ProcessRunner().run(request, output: output.add) else { return nil }
        let text = (output.lines(of: .standardOutput) + output.lines(of: .standardError)).joined(separator: "\n")
        return outcome.succeeded || !text.isEmpty ? text : nil
    }
}
