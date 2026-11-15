// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The Android host's suite: its tests a test APK run by its instrumentation on a device or emulator - every test
/// listed, the screen kept on and put back - then what the host declares and every family's verdicts held to their
/// records, and the facade to its API record; or the test APK built alone, with its identity, to run elsewhere.
/// Design: docs/design/tooling/repository.md#the-android-hosts-suite
struct AndroidSuite {
    let checkout: URL
    let tools: ToolResolver
    /// Whether the API phase writes its records rather than holds them.
    var recordingAPI = false
    let android: AndroidTools
    let destinations: @Sendable () async -> [Destination]

    /// What a test APK built alone says of itself, checked before it runs elsewhere.
    struct Identity: Codable, Equatable {
        var suite: String
        var architecture: Architecture
        /// The checkout's commit it was built from; empty outside git.
        var revision: String
        var swiftSDK: String
    }

    private var tests: URL { checkout.appendingPathComponent("lib/StateUI/StateUI.Android/Tests") }
    private let product = "StateUIAndroidTests"

    func run(
        device: String?, filter: String?, buildOnly: Bool, architecture: Architecture?, artifact: URL?,
        recording revisions: [String: String]? = nil, environment: ProcessEnvironment, reporter: BuildReporter
    ) async throws -> SuiteResult {
        let unlisted = try Self.unlisted(in: tests.appendingPathComponent("Sources"))
        guard unlisted.isEmpty else {
            throw ToolingError(.invalidConfiguration, "Listed nowhere, so never run: \(unlisted.joined(separator: ", ")).")
        }
        if buildOnly {
            guard let architecture else { throw ToolingError(.invalidConfiguration, "Name the architecture the test APK is built for: arm64 or x86_64.") }
            let built = try await build(architecture, environment: environment, reporter: reporter)
            return SuiteResult(suite: "host:android", phases: [SuiteResult.Phase(name: "build", passed: true)], artifactUri: FileURI.string(built.folder))
        }

        var target = try AndroidDestinations.choose(device, from: await destinations(), environment: ProcessInfo.processInfo.environment)
        if !target.booted, target.kind == .emulator { target = try await AndroidDestinations(tools: android).boot(target.id, reporter: reporter) }
        guard let deviceArchitecture = target.architecture else {
            throw ToolingError(.invalidConfiguration, "\(target.name) does not say its ABI.")
        }
        var built: Built?
        let folder: URL
        if let artifact {
            folder = artifact
            try await check(artifact, for: deviceArchitecture)
        } else {
            built = try await build(deviceArchitecture, environment: environment, reporter: reporter)
            folder = built!.folder
        }
        let apk = folder.appendingPathComponent("\(product).apk")
        let (package, _) = try await AndroidHead.badging(of: apk, tools: android)
        let passed = try await runTests(apk, package: package, on: target, filter: filter, reporter: reporter)
        var phases = [SuiteResult.Phase(name: "tests", passed: passed)]
        // The device reads no repository: what a run proved is held to the records here, or written there.
        let declared = filter.map { $0.contains("AndroidDeclarationExportTests") } ?? true
        if passed, let revisions {
            phases.append(try await recordMarks(package: package, on: target, revisions: revisions, declared: declared, reporter: reporter))
        } else if passed, filter == nil || filter?.contains("AndroidConformanceTests") == true {
            phases += try await holdRecords(package: package, on: target, whole: filter == nil, declared: declared, reporter: reporter)
        }
        if let built {
            phases.append(SuiteResult.Phase(name: "api StateUIAndroid", passed: try await recordAPI(built, environment: environment, reporter: reporter)))
        }
        return SuiteResult(suite: "host:android", phases: phases)
    }

    /// The tests no list names, so none would run: a `func test` its file's `allTests` leaves out, a case the runner
    /// does not name.
    static func unlisted(in sources: URL) throws -> [String] {
        let files = FileManager.default
        let paths = ((files.enumerator(atPath: sources.path)?.allObjects as? [String]) ?? []).filter { $0.hasSuffix(".swift") }.sorted()
        let runner = paths.first { $0.hasSuffix("AndroidTestRunner.swift") }
            .flatMap { try? String(contentsOf: sources.appendingPathComponent($0), encoding: .utf8) } ?? ""
        var missing: [String] = []
        for path in paths {
            let text = try String(contentsOf: sources.appendingPathComponent(path), encoding: .utf8)
            missing += unlisted(in: text, runner: runner)
        }
        return missing
    }

    /// The tests of the source `text` no list names: its own `allTests`, the runner's `testCase(...)`.
    static func unlisted(in text: String, runner: String) -> [String] {
        let tests = text.matches(of: /func (test[A-Za-z0-9_]+)\(\)/).map { String($0.1) }
            .filter { !text.contains("(\"\($0)\", \($0))") }
        let cases = text.matches(of: /class ([A-Za-z0-9_]+): XCTestCase/).map { String($0.1) }
            .filter { !runner.contains("testCase(\($0).allTests)") }
        return tests + cases
    }

    // MARK: Building

    struct Built {
        var folder: URL
        var binaries: URL
        var triple: String
        var swiftSDK: String
        var compiler: ProcessExecutable
    }

    /// The test APK built for `architecture` and laid with its identity in a folder of its own.
    private func build(_ architecture: Architecture, environment: ProcessEnvironment, reporter: BuildReporter) async throws -> Built {
        let target = try await BuildTarget.android(device: nil, listed: [], architecture: architecture, tools: android)
        guard let (swiftSDK, ndk) = target.android, let compiler = target.compiler, let abi = AndroidDestinations.abi(of: architecture) else {
            throw ToolingError(.internalError, "The Android target named no Swift SDK.")
        }
        let context = BuildContext(
            application: tests, product: product, host: .android, configuration: .debug, architecture: architecture,
            compiler: (await ToolOutput.text(compiler, ["--version"]))?.split(separator: "\n").first.map(String.init) ?? "",
            sdk: target.sdkIdentity, library: checkout)
        let common = ["--package-path", tests.path, "--scratch-path", context.scratch.path, "--configuration", "debug"] + target.arguments
        let building = target.environment.reduce(environment.setting("STATEUI_HOST", to: "android")) { $0.setting($1.key, to: $1.value) }
        reporter.progress("building the Android host's tests for \(abi)")
        let outcome = try await ProcessRunner().run(
            ProcessRequest(compiler, arguments: ["build", "--product", product] + common, environment: building), output: reporter.output)
        try Task.checkCancellation()
        guard outcome.succeeded,
              let binaries = (await ToolOutput.text(compiler, ["build", "--show-bin-path"] + common, environment: building))?
                .split(separator: "\n").last.map({ URL(fileURLWithPath: String($0).trimmingCharacters(in: .whitespaces)) })
        else { throw ToolingError(.toolFailed, "The Android host's tests did not build.") }

        let work = context.scratch.appendingPathComponent("stateui")
        let folder = work.appendingPathComponent("suite")
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let head = AndroidHead(
            application: tests, name: product, product: product, library: checkout, configuration: .debug, work: work, tools: android)
        _ = try await head.assemble(abi: abi, binaries: binaries, swiftSDK: swiftSDK, ndk: ndk, in: folder, reporter: reporter)
        let identity = Identity(suite: "host:android", architecture: architecture, revision: await revision(), swiftSDK: swiftSDK)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(identity).write(to: folder.appendingPathComponent("suite.json"))
        return Built(folder: folder, binaries: binaries, triple: target.arguments.last ?? "", swiftSDK: swiftSDK, compiler: compiler)
    }

    /// The checkout's commit, or empty outside git.
    private func revision() async -> String {
        (await ToolOutput.standardOutput(.name("git"), ["-C", checkout.path, "rev-parse", "HEAD"]) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Refuses a test APK built for another suite, architecture or commit than this run's.
    private func check(_ artifact: URL, for architecture: Architecture) async throws {
        guard let data = try? Data(contentsOf: artifact.appendingPathComponent("suite.json")),
              let identity = try? JSONDecoder().decode(Identity.self, from: data)
        else { throw ToolingError(.invalidConfiguration, "\(artifact.path) holds no suite.json: build it with --build-only.") }
        guard identity.suite == "host:android" else {
            throw ToolingError(.invalidConfiguration, "\(artifact.path) is \(identity.suite)'s, not host:android's.")
        }
        guard identity.architecture == architecture else {
            throw ToolingError(.invalidConfiguration, "The test APK is built for \(identity.architecture.rawValue), the device runs \(architecture.rawValue).")
        }
        let here = await revision()
        guard identity.revision.isEmpty || here.isEmpty || identity.revision == here else {
            throw ToolingError(.invalidConfiguration, "The test APK was built from \(identity.revision), this checkout stands at \(here).")
        }
    }

    // MARK: Running

    /// The tests run on `device` by their instrumentation, each line saying where the run stands followed from the
    /// device's log; the screen kept on for the run and put back; whether the run's last word says no failure.
    private func runTests(_ apk: URL, package: String, on device: Destination, filter: String?, reporter: BuildReporter) async throws -> Bool {
        let adb = ProcessExecutable.path(android.adb.path)
        let shell = { (arguments: [String]) in ["-s", device.id, "shell"] + arguments }
        reporter.progress("installing on \(device.name)")
        try await ToolStep.run(adb, ["-s", device.id, "install", "-r", apk.path], limit: .seconds(600))
        // The verdicts of a run before this one stay in the APK's files: none may stand for this run's.
        try await ToolStep.run(adb, shell(["run-as", package, "rm", "-rf", "files/marks"]))

        let stayOn = (await ToolOutput.standardOutput(adb, shell(["settings", "get", "global", "stay_on_while_plugged_in"])) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let awake = ["0": "false", "1": "ac", "2": "usb", "4": "wireless"][stayOn] ?? "true"
        // A phone may refuse the power service to the shell: its own "Stay awake" then holds.
        await ToolStep.regardless(adb, shell(["svc", "power", "stayon", "usb"]))
        await ToolStep.regardless(adb, shell(["input", "keyevent", "KEYCODE_WAKEUP"]))
        await ToolStep.regardless(adb, shell(["wm", "dismiss-keyguard"]))

        await ToolStep.regardless(adb, ["-s", device.id, "logcat", "-c"])
        let follower = Task {
            try await ProcessRunner().run(ProcessRequest(adb, arguments: ["-s", device.id, "logcat", "-v", "raw", "-s", "StateUI"]), output: { line in
                if line.text.firstMatch(of: /\[\d+\/\d+\]/) != nil { reporter.output(line) }
            })
        }
        let said = Gathered()
        reporter.progress("running the Android host's tests on \(device.name)")
        let instrument = shell(["am", "instrument", "-w"] + (filter.map { ["-e", "filter", $0] } ?? []) + ["\(package)/stateui.android.test.StateUITestRunner"])
        var failure: (any Error)?
        do {
            _ = try await ProcessRunner().run(ProcessRequest(adb, arguments: instrument), output: { line in
                said.add(line)
                reporter.output(line)
            })
        } catch {
            failure = error
        }
        follower.cancel()
        _ = try? await follower.value
        await ToolStep.regardless(adb, shell(["svc", "power", "stayon", awake]))
        if let failure { throw failure }
        try Task.checkCancellation()

        let summary = said.lines(of: .standardOutput).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .last { $0.firstMatch(of: /^Executed \d+ tests?, with \d+ failures?/) != nil }
        guard let summary else {
            reporter.output(ProcessOutput(stream: .standardError, text: "The tests reported nothing - read: adb -s \(device.id) logcat -s StateUI"))
            return false
        }
        if filter != nil, summary.hasPrefix("Executed 0 tests") {
            reporter.output(ProcessOutput(stream: .standardError, text: "No test matched \(filter ?? ""): a run of none proves nothing."))
            return false
        }
        if !summary.contains(" with 0 failures") {
            // What the system did to the tests' window, said, so a failure nobody watched names its cause.
            let log = await ToolOutput.standardOutput(adb, ["-s", device.id, "logcat", "-d", "-v", "time"]) ?? ""
            for line in log.split(separator: "\n").suffix(4000)
                where line.contains("Denying clipboard access to \(package)") || line.contains("ANR in") || line.contains("isn't responding") {
                reporter.output(ProcessOutput(stream: .standardError, text: String(line)))
            }
            return false
        }
        return true
    }

    /// What the host declares, and every family's verdicts, taken off the device and held to their records.
    private func holdRecords(
        package: String, on device: Destination, whole: Bool, declared: Bool, reporter: BuildReporter
    ) async throws -> [SuiteResult.Phase] {
        let adb = ProcessExecutable.path(android.adb.path)
        let read = { (file: String) async in
            await ToolOutput.standardOutput(adb, ["-s", device.id, "exec-out", "run-as", package, "cat", file]) ?? ""
        }
        let exports = checkout.appendingPathComponent("lib/StateUI/exports")
        let kept = (try? String(contentsOf: exports.appendingPathComponent("android.txt"), encoding: .utf8)) ?? ""
        let declarationsHeld = declared ? Self.lines(await read("files/android.txt")) == Self.lines(kept) : true
        if !declarationsHeld {
            reporter.output(ProcessOutput(stream: .standardError, text:
                "lib/StateUI/exports/android.txt is not what the host declares - a registration changed, or something stopped being realized."))
        }

        let names = (await ToolOutput.standardOutput(adb, ["-s", device.id, "exec-out", "run-as", package, "ls", "files/marks/android"]) ?? "")
            .split(whereSeparator: \.isWhitespace).map(String.init).filter { $0.hasSuffix(".txt") }.sorted()
        let marks = exports.appendingPathComponent("marks/android")
        let recorded = ((try? FileManager.default.contentsOfDirectory(atPath: marks.path)) ?? []).filter { $0.hasSuffix(".txt") }.sorted()
        var differ: [String] = []
        if whole, names != recorded { differ.append("the families run (\(names.count)) are not those recorded (\(recorded.count))") }
        if names.isEmpty { differ.append("no family's verdicts were proved") }
        for name in names {
            let run = Self.verdicts(await read("files/marks/android/\(name)"))
            let held = Self.verdicts((try? String(contentsOf: marks.appendingPathComponent(name), encoding: .utf8)) ?? "")
            if Self.lines(run) != Self.lines(held) { differ.append(name) }
        }
        if !differ.isEmpty {
            reporter.output(ProcessOutput(stream: .standardError, text:
                "lib/StateUI/exports/marks/android is not what this run proved: \(differ.prefix(12).joined(separator: ", "))."))
        }
        return (declared ? [SuiteResult.Phase(name: "declarations android.txt", passed: declarationsHeld)] : [])
            + [SuiteResult.Phase(name: "marks android", passed: differ.isEmpty)]
    }

    /// Every family's verdicts the run proved, taken off the device and written into the repository's marks, each
    /// under the revision `revisions` gives its family - the device reads no repository.
    private func recordMarks(
        package: String, on device: Destination, revisions: [String: String], declared: Bool, reporter: BuildReporter
    ) async throws -> SuiteResult.Phase {
        let adb = ProcessExecutable.path(android.adb.path)
        let marks = checkout.appendingPathComponent("lib/StateUI/exports/marks/android")
        if declared {
            let declaration = await ToolOutput.standardOutput(
                adb, ["-s", device.id, "exec-out", "run-as", package, "cat", "files/android.txt"], limit: .seconds(60)) ?? ""
            if !declaration.isEmpty {
                try Data((declaration.hasSuffix("\n") ? declaration : declaration + "\n").utf8)
                    .write(to: marks.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("android.txt"))
            }
        }
        let names = (await ToolOutput.standardOutput(adb, ["-s", device.id, "exec-out", "run-as", package, "ls", "files/marks/android"]) ?? "")
            .split(whereSeparator: \.isWhitespace).map(String.init).filter { $0.hasSuffix(".txt") }.sorted()
        for name in names {
            let proved = await ToolOutput.standardOutput(
                adb, ["-s", device.id, "exec-out", "run-as", package, "cat", "files/marks/android/\(name)"], limit: .seconds(60)) ?? ""
            let revision = revisions[Self.family(of: name)] ?? "1.1"
            // Read line by line, the text lost the line end every verdict file closes with.
            try Data("# revision \(revision)\n\(proved)\(proved.hasSuffix("\n") ? "" : "\n")".utf8).write(to: marks.appendingPathComponent(name))
        }
        reporter.progress("recorded \(names.count) verdict files of Android's")
        return SuiteResult.Phase(name: "marks android recorded", passed: !names.isEmpty)
    }

    /// The family a verdict file is of: `Button.txt`, a part's `VisualElement-3.txt`.
    static func family(of file: String) -> String {
        let name = String(file.dropLast(file.hasSuffix(".txt") ? 4 : 0))
        guard let dash = name.lastIndex(of: "-"), Int(name[name.index(after: dash)...]) != nil else { return name }
        return String(name[..<dash])
    }

    /// A verdict file's verdicts, the line naming its revision aside: two runs at other revisions compare by them.
    static func verdicts(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).filter { !$0.hasPrefix("# revision ") }.joined(separator: "\n")
    }

    /// `text`'s lines, line ends and a last empty line aside: a device's answer ends lines as it does.
    private static func lines(_ text: String) -> [String] {
        var lines = text.replacingOccurrences(of: "\r", with: "").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        while lines.last == "" { lines.removeLast() }
        return lines
    }

    /// The facade the build made, held to its API record for the ABI's triple and the Swift SDK.
    private func recordAPI(_ built: Built, environment: ProcessEnvironment, reporter: BuildReporter) async throws -> Bool {
        reporter.progress("checking the API record")
        let shown = await ToolOutput.text(built.compiler, ["sdk", "configure", "--show-configuration", built.swiftSDK, built.triple]) ?? ""
        let value = { (key: String) in
            shown.split(separator: "\n").first { $0.hasPrefix("\(key): ") }.map { String($0.dropFirst(key.count + 2)) } ?? ""
        }
        let android = checkout.appendingPathComponent("lib/StateUI/StateUI.Android/Sources/CStateUIAndroid/include/module.modulemap").path
        let host = checkout.appendingPathComponent("lib/StateUI/StateUI.Host/CStateUIHost/module.modulemap").path
        let arguments = ["-resource-dir", value("swiftResourcesPath"), "-Xcc", "-fmodule-map-file=\(android)", "-Xcc", "-fmodule-map-file=\(host)"]
        let held = environment.forAPIRecord(recording: recordingAPI).setting("STATEUI_API_MODULE", to: "StateUIAndroid")
            .setting("STATEUI_API_MODULES", to: built.binaries.path).setting("STATEUI_API_TRIPLE", to: built.triple)
            .setting("STATEUI_API_SDK", to: value("sdkRootPath")).setting("STATEUI_API_ARGUMENTS", to: arguments.joined(separator: "\n"))
        let outcome = try await ProcessRunner().run(ProcessRequest(tools.swift, arguments: [
            "test", "--package-path", checkout.path, "--filter", "APISurfaceTests/testTheModuleAHostsScriptNamesIsItsRecord",
        ], environment: held), output: reporter.output)
        try Task.checkCancellation()
        return outcome.succeeded
    }
}
