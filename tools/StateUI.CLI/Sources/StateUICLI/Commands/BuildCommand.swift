// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

/// What names one build: the project, the application, its host, configuration, architecture and device.
struct BuildOptions: ParsableArguments {
    @Option(help: "A folder of the project; the working directory when left out.")
    var project: String?

    @Option(help: "The application, where the project holds more than one.")
    var application: String?

    @Option(help: "The host it is built for: appkit, uikit or android.")
    var host: HostFamily

    @Option(help: "debug or release; debug for a build and a run, release for a package.")
    var configuration: BuildConfiguration?

    @Option(help: "The architecture it is built for; left out, this machine's for AppKit, the device's for UIKit and Android.")
    var architecture: Architecture?

    @Option(help: "A UIKit head's device or simulator, an Android head's device or emulator, by name or id (stateui devices --host <host>); left out, the booted simulator, else an iPhone - the only Android device running.")
    var device: String?

    /// The request these options name, laid in `output` where given.
    func request(output: String? = nil) -> BuildRequest {
        BuildRequest(
            projectUri: project.map { FileURI.string(URL(fileURLWithPath: $0)) }, application: application, host: host,
            configuration: configuration, architecture: architecture, device: device, outputUri: output.map { FileURI.string(URL(fileURLWithPath: $0)) })
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

    /// The words naming the device or simulator a build was for, where it was for one.
    static func destination(of built: BuildResult) -> String {
        built.destination.map { " for \($0.name) (\($0.kind.rawValue), \($0.version))" } ?? ""
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
        }) { built in "Built \((try? FileURI.url(built.programUri).path) ?? built.programUri)\(BuildOptions.destination(of: built))" }
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
        }) { laid in "Packaged \((try? FileURI.url(laid.folderUri).path) ?? laid.folderUri)\(BuildOptions.destination(of: laid))" }
    }
}

/// `stateui run`: an application built, then run in the foreground until it ends or Ctrl+C stops it - an AppKit
/// head on this Mac, a UIKit head on its device or simulator, its output followed.
struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run", abstract: "Builds an application and runs it in the foreground; Ctrl+C stops it.")

    @OptionGroup var build: BuildOptions

    @Flag(help: "Start a UIKit head held until a debugger attaches; its process is said as it starts.")
    var debugger = false

    func run() async throws {
        do {
            if build.host == .uikit {
                _ = try await ToolingService().run(
                    RunRequest(build: build.request(), debugger: debugger), in: build.here, operation: BuildOptions.operation,
                    reporter: RunReporter(
                        build: BuildOptions.terminal, started: { FileHandle.standardError.write(Data((Self.words($0) + "\n").utf8)) },
                        output: { line in
                            (line.stream == .standardError ? FileHandle.standardError : FileHandle.standardOutput)
                                .write(Data((line.text + "\n").utf8))
                        }))
                return
            }
            let built = try await ToolingService().build(build.request(), in: build.here, operation: BuildOptions.operation, reporter: BuildOptions.terminal)
            let program = try FileURI.url(built.programUri)
            FileHandle.standardError.write(Data("stateui: running \(program.path)\n".utf8))
            let outcome = try await ProcessRunner().run(ProcessRequest(.path(program.path), streams: .terminal))
            if case .exited(let status) = outcome.termination, status != 0 { throw ExitCode(Int32(status)) }
        } catch let error as ToolingError {
            try OutputFormat.text.write(error)
            throw ExitCode(ExitStatus.of(error))
        }
    }

    /// What a run says as its application starts: where, as which process, and whether it waits for a debugger.
    static func words(_ launched: LaunchedApplication) -> String {
        let place = launched.build.destination.map { " on \($0.name)" } ?? ""
        let process = launched.process.map { ", process \($0)" } ?? ""
        return "stateui: started \(launched.build.application)\(place)\(process)\(launched.held ? ", held for a debugger" : "")"
    }
}
