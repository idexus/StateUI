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

    @Option(help: "The host it is built for: appkit, uikit, android, winui, gtk or web; the one chosen (stateui settings) when left out.")
    var host: HostFamily?

    @Option(help: "debug or release; debug for a build and a run, release for a package.")
    var configuration: BuildConfiguration?

    @Option(help: "The architecture it is built for; left out, this machine's for AppKit, WinUI and GTK, the device's for UIKit and Android, the guest's for GTK and WinUI in a guest - on Windows arm64 or x86_64, the other run by Windows' emulation.")
    var architecture: Architecture?

    @Option(help: "A UIKit head's device or simulator, an Android head's device or emulator, a Web head's browser, a GTK or WinUI head's guest on a Mac, by name or id (stateui devices --host <host>); left out, the one chosen for the host (stateui settings), else the booted simulator, else an iPhone - the only Android device running.")
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
        }) { built in "Built \(FileURI.shown(built.programUri))\(BuildOptions.destination(of: built))" }
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
/// head on this Mac, a UIKit or Android head on its device, simulator or emulator, its output followed.
struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run", abstract: "Builds an application and runs it in the foreground; Ctrl+C stops it.")

    @OptionGroup var build: BuildOptions

    @Option(help: "A Web head's page's port; 8460, else another free, when left out.")
    var port: Int?

    @Option(help: "A Web head's page served on this machine alone, loopback, or shared with the network, lan.")
    var listen: String?

    @Flag(help: "Ready a debugger: a UIKit head starts held until one attaches, an Android head with the debugger's server in its sandbox - what to attach to said as it starts; a GTK head runs under gdb, each GTK critical's stack and a crash's said as they come.")
    var debugger = false

    func run() async throws {
        do {
            let request = try ApplicationBuilder.chosen(build.request(), in: build.here)
            let remotes = try RemoteMachines(project: build.project.map { URL(fileURLWithPath: $0) } ?? build.here).list()
            if let host = request.host, [.uikit, .android, .web].contains(host) || RemoteWork.asks(host, device: request.device, remotes: remotes) {
                guard listen == nil || ["loopback", "lan"].contains(listen ?? "") else {
                    throw ToolingError(.invalidConfiguration, "--listen is loopback or lan.")
                }
                _ = try await ToolingService().run(
                    RunRequest(build: request, debugger: debugger, port: port, lan: listen.map { $0 == "lan" }), in: build.here,
                    operation: BuildOptions.operation,
                    reporter: RunReporter(
                        build: BuildOptions.terminal, started: { FileHandle.standardError.write(Data((Self.words($0) + "\n").utf8)) },
                        output: { line in
                            (line.stream == .standardError ? FileHandle.standardError : FileHandle.standardOutput)
                                .write(Data((line.text + "\n").utf8))
                        }))
                return
            }
            let built = try await ToolingService().build(request, in: build.here, operation: BuildOptions.operation, reporter: BuildOptions.terminal)
            let program = try FileURI.url(built.programUri)
            if request.host == .gtk {
                // A GTK application is one instance: a second start would only bring a running copy forward.
                _ = try await ToolingService().install(try FileURI.url(built.folderUri))
                _ = try? await ProcessRunner().run(ProcessRequest(.name("pkill"), arguments: ["-f", "^\(program.path)( |$)"]))
            }
            FileHandle.standardError.write(Data("stateui: running \(program.path)\n".utf8))
            var started = ProcessRequest(.path(program.path), streams: .terminal)
            let commands = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-gdb-\(UUID().uuidString).cmd")
            defer { try? FileManager.default.removeItem(at: commands) }
            if request.host == .gtk, debugger {
                // Under gdb, each GTK critical's stack and a crash's are said as they come.
                try Data(ToolingService.gdbCommands(for: built.architecture).utf8).write(to: commands)
                started = ProcessRequest(
                    .name("gdb"), arguments: ["-batch", "-x", commands.path, "--args", program.path],
                    environment: ProcessEnvironment.inherited.setting("SWIFT_BACKTRACE", to: "enable=no"), streams: .terminal)
            }
            let outcome = try await ProcessRunner().run(started)
            if outcome.exitStatus != 0 { throw ExitCode(outcome.exitStatus) }
        } catch let error as ToolingError {
            try OutputFormat.text.write(error)
            throw ExitCode(ExitStatus.of(error))
        }
    }

    /// What a run says as its application starts: where, as which process, whether it waits for a debugger, and the
    /// commands that bring LLDB to it, where the run readied one.
    static func words(_ launched: LaunchedApplication) -> String {
        let place = launched.build.destination.map { " on \($0.name)" } ?? ""
        let process = launched.process.map { ", process \($0)" } ?? ""
        let lldb = launched.debugger.flatMap { way -> String? in
            guard way.kind == .lldb else { return nil }
            let attach = way.attachCommands.isEmpty ? way.process.map { ["process attach --pid \($0)"] } ?? [] : way.attachCommands
            return "\nstateui: LLDB reaches it with: " + (way.initCommands + attach).joined(separator: "; ")
        } ?? ""
        if let url = launched.url { return "stateui: serving \(launched.build.application) at \(url)" }
        return "stateui: started \(launched.build.application)\(place)\(process)\(launched.held ? ", held for a debugger" : "")\(lldb)"
    }
}

/// `stateui install`: a built application installed where its host shows it, never built again - a GTK head's desktop
/// entry and icon for the user.
struct InstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install", abstract: "Installs a built application where its host shows it: a GTK head's desktop entry and icon.")

    @Option(help: "The artifact's folder, as stateui build said it.")
    var artifact: String

    @OptionGroup var output: OutputOptions

    func run() async throws {
        try await output.answer({ try await ToolingService().install(URL(fileURLWithPath: artifact)) }) { installed in
            installed.writtenUris.isEmpty ? "Nothing to install." : installed.writtenUris.map { "Wrote \((try? FileURI.url($0).path) ?? $0)" }.joined(separator: "\n")
        }
    }
}
