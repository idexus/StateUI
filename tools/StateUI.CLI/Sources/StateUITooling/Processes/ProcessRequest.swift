// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A program to run: its executable and its arguments as an array - never a line a shell reads - with the
/// environment, directory, time limit and streams it runs with.
public struct ProcessRequest: Sendable {
    /// The program.
    public var executable: ProcessExecutable
    /// The arguments, each reaching the program as written.
    public var arguments: [String]
    /// The environment the program starts with.
    public var environment: ProcessEnvironment
    /// The directory the program starts in; this tool's own when `nil`.
    public var workingDirectory: String?
    /// How long the program may run before it is stopped; no limit when `nil`.
    public var timeout: Duration?
    /// How long a program asked to stop has before it is killed.
    public var gracePeriod: Duration
    /// Where the program's standard streams go.
    public var streams: ProcessStreams

    /// A request to run `executable` with `arguments`.
    public init(
        _ executable: ProcessExecutable,
        arguments: [String] = [],
        environment: ProcessEnvironment = .inherited,
        workingDirectory: String? = nil,
        timeout: Duration? = nil,
        gracePeriod: Duration = .seconds(5),
        streams: ProcessStreams = .captured
    ) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = workingDirectory
        self.timeout = timeout
        self.gracePeriod = gracePeriod
        self.streams = streams
    }
}
