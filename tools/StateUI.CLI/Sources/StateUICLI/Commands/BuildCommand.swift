// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

/// What names one build: the project, the application, its host, configuration and architecture.
struct BuildOptions: ParsableArguments {
    @Option(help: "A folder of the project; the working directory when left out.")
    var project: String?

    @Option(help: "The application, where the project holds more than one.")
    var application: String?

    @Option(help: "The host it is built for: appkit.")
    var host: HostFamily

    @Option(help: "debug or release; debug for a build and a run, release for a package.")
    var configuration: BuildConfiguration?

    @Option(help: "The architecture it is built for; this machine's when left out.")
    var architecture: Architecture?

    /// The request these options name, laid in `output` where given.
    func request(output: String? = nil) -> BuildRequest {
        BuildRequest(
            projectUri: project.map { FileURI.string(URL(fileURLWithPath: $0)) }, application: application, host: host,
            configuration: configuration, architecture: architecture, outputUri: output.map { FileURI.string(URL(fileURLWithPath: $0)) })
    }

    /// The folder a project is read from where none is named.
    var here: URL { URL(fileURLWithPath: FileManager.default.currentDirectoryPath) }

    /// What a build says on the terminal: its progress and its programs' words on standard error, so standard
    /// output holds the result alone.
    static var terminal: BuildReporter {
        BuildReporter(
            progress: { FileHandle.standardError.write(Data("stateui: \($0)\n".utf8)) },
            output: { FileHandle.standardError.write(Data(($0.text + "\n").utf8)) })
    }

    /// An operation's id of its own.
    static var operation: String { "cli-\(UUID().uuidString.lowercased())" }
}

extension BuildConfiguration: ExpressibleByArgument {}
extension Architecture: ExpressibleByArgument {}

/// `stateui build`: an application built for a host and published.
struct BuildCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build", abstract: "Builds an application for a host and publishes what it built.")

    @OptionGroup var build: BuildOptions
    @OptionGroup var output: OutputOptions

    func run() async throws {
        try await output.answer({
            try await ToolingService().build(build.request(), in: build.here, operation: BuildOptions.operation, reporter: BuildOptions.terminal)
        }) { built in "Built \((try? FileURI.url(built.programUri).path) ?? built.programUri)" }
    }
}

/// `stateui package`: an application built for release and laid out to be shipped.
struct PackageCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "package", abstract: "Builds an application for release and lays it out to be shipped.")

    @OptionGroup var build: BuildOptions

    @Option(help: "The folder it is laid in, made anew; <workspace>/artifacts/<Name>/<Host> when left out.")
    var output: String?

    @OptionGroup var format: OutputOptions

    func run() async throws {
        try await format.answer({
            try await ToolingService().package(
                build.request(output: output), in: build.here, operation: BuildOptions.operation, reporter: BuildOptions.terminal)
        }) { laid in "Packaged \((try? FileURI.url(laid.folderUri).path) ?? laid.folderUri)" }
    }
}

/// `stateui run`: an application built, then run in the foreground until it ends or Ctrl+C stops it.
struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run", abstract: "Builds an application and runs it in the foreground; Ctrl+C stops it.")

    @OptionGroup var build: BuildOptions

    func run() async throws {
        let built: BuildResult
        do {
            built = try await ToolingService().build(build.request(), in: build.here, operation: BuildOptions.operation, reporter: BuildOptions.terminal)
        } catch let error as ToolingError {
            try OutputFormat.text.write(error)
            throw ExitCode(ExitStatus.of(error))
        }
        let program = try FileURI.url(built.programUri)
        FileHandle.standardError.write(Data("stateui: running \(program.path)\n".utf8))
        let outcome = try await ProcessRunner().run(ProcessRequest(.path(program.path), streams: .terminal))
        if case .exited(let status) = outcome.termination, status != 0 { throw ExitCode(Int32(status)) }
    }
}
