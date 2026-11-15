// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// An Android head installed on a device or emulator, started with what the run hands it of the tool's environment,
/// its log followed until it ends; for a debugger, the NDK's `lldb-server` readied in the application's sandbox. A stop
/// ends the application, the log's follower and the server.
/// Design: docs/design/tooling/runs.md#on-android
struct AndroidLaunch {
    var device: Destination
    var apk: URL
    var package: String
    var activity: String
    /// The NDK the build used: its `lldb-server` for the device's ABI.
    var ndk: URL?
    var tools: AndroidTools
    /// What the run hands the application of the tool's environment.
    var environment: HandedEnvironment

    /// `am start`'s words handing the application `environment`: each variable an extra.
    static func switches(_ environment: HandedEnvironment) -> [String] {
        environment.sorted.flatMap { ["-e", $0.name, $0.value] }
    }

    func run(_ built: BuildResult, debugger: Bool, reporter: RunReporter) async throws -> RunResult {
        let adb = ProcessExecutable.path(tools.adb.path)
        let serial = device.id
        reporter.build.progress("installing on \(device.name)")
        try await ToolStep.run(adb, ["-s", serial, "install", "-r", apk.path], limit: .seconds(600))
        try await ToolStep.run(adb, ["-s", serial, "shell", "am", "force-stop", package])
        reporter.build.progress("starting \(package)")
        let switches = Self.switches(environment)
        try await ToolStep.run(adb, ["-s", serial, "shell", "am", "start", "-W", "-n", "\(package)/\(activity)"] + switches, limit: .seconds(120))
        var process: Int?
        for _ in 0..<10 where process == nil {
            process = await pid(adb)
            if process == nil { try await Task.sleep(for: .milliseconds(500)) }
        }
        guard let process else { throw ToolingError(.toolFailed, "\(package) did not start on \(device.name).") }
        let socket = debugger ? try await readyDebugger(adb) : nil

        let launched = LaunchedApplication(build: built, process: process, held: false, debuggerSocket: socket)
        let log = Task {
            try await ProcessRunner().run(
                ProcessRequest(adb, arguments: ["-s", serial, "logcat", "-v", "brief", "--pid=\(process)"]), output: reporter.output)
        }
        reporter.started(launched)
        defer { log.cancel() }
        // A cancelled run's own asking is cancelled too, and says no process: the stop is decided by the cancel, not by it.
        while !Task.isCancelled, await pid(adb) == process {
            try? await Task.sleep(for: .seconds(1))
        }
        let cancelled = Task.isCancelled
        if cancelled {
            await ToolStep.regardless(adb, ["-s", serial, "shell", "am", "force-stop", package])
        }
        if socket != nil {
            await ToolStep.regardless(adb, ["-s", serial, "shell", "run-as", package, "pkill", "-x", "lldb-server"])
        }
        log.cancel()
        _ = try? await log.value
        if cancelled { throw CancellationError() }
        return RunResult(launched: launched, exitStatus: nil)
    }

    /// The application's process on the device, while it runs.
    private func pid(_ adb: ProcessExecutable) async -> Int? {
        (await ToolOutput.standardOutput(adb, ["-s", device.id, "shell", "pidof", package]))
            .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    /// The NDK's `lldb-server` for the device's ABI, run as the application - which a debug build allows - in its own
    /// folder, listening on an abstract socket named after the package; a server of an earlier run stopped first, and
    /// the new one renamed into place, since a running server's file cannot be written over. Answers the socket.
    private func readyDebugger(_ adb: ProcessExecutable) async throws -> String {
        let names: [Architecture: String] = [.arm64: "aarch64", .x86_64: "x86_64", .armv7: "arm", .x86: "i386"]
        guard let ndk, let architecture = device.architecture, let name = names[architecture] else {
            throw ToolingError(.toolFailed, "The debugger's server for \(device.name) is not known: the NDK or its ABI is missing.")
        }
        let files = FileManager.default
        let listed = { (folder: URL) in ((try? files.contentsOfDirectory(atPath: folder.path)) ?? []).sorted { Versions.compare($0, $1) < 0 } }
        let prebuilt = ndk.appendingPathComponent("toolchains/llvm/prebuilt")
        let servers = listed(prebuilt).flatMap { host in
            let clang = prebuilt.appendingPathComponent(host).appendingPathComponent("lib/clang")
            return listed(clang).map { clang.appendingPathComponent($0).appendingPathComponent("lib/linux/\(name)/lldb-server") }
        }
        let server = servers.last { files.fileExists(atPath: $0.path) }
        guard let server else { throw ToolingError(.toolFailed, "The NDK at \(ndk.path) has no lldb-server for \(name).") }
        let socket = "\(package)/stateui-debugger.sock"
        try await ToolStep.run(adb, ["-s", device.id, "push", server.path, "/data/local/tmp/stateui-lldb-server"])
        try await ToolStep.run(adb, ["-s", device.id, "shell", "run-as \(package) sh -c 'pkill -x lldb-server; cp /data/local/tmp/stateui-lldb-server lldb-server.new && chmod 700 lldb-server.new && mv lldb-server.new lldb-server'"])
        try await ToolStep.run(adb, ["-s", device.id, "shell", "run-as \(package) sh -c './lldb-server platform --server --listen unix-abstract:///\(socket) </dev/null >/dev/null 2>&1 &'"])
        return socket
    }
}
