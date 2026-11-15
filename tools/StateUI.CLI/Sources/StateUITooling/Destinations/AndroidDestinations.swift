// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The Android devices and emulators a head runs on: those `adb` lists attached and ready - each with its model or its
/// emulator's virtual device, its Android version and its ABI - then the virtual devices not running, which a run
/// boots; and the one a run means.
/// Design: docs/design/tooling/destinations.md#android
public struct AndroidDestinations: Sendable {
    private let tools: AndroidTools

    /// The destinations `tools`' `adb` and emulator list.
    public init(tools: AndroidTools = AndroidTools()) {
        self.tools = tools
    }

    /// The attached devices and running emulators, then the virtual devices not running.
    public func list() async -> [Destination] {
        let adb = ProcessExecutable.path(tools.adb.path)
        let lines = await ToolOutput.standardOutput(adb, ["devices", "-l"]) ?? ""
        var listed: [Destination] = []
        for each in Self.attached(fromADB: lines) {
            let asked = { (property: String) async in
                (await ToolOutput.standardOutput(adb, ["-s", each.serial, "shell", "getprop", property]) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let abi = await asked("ro.product.cpu.abi")
            let version = await asked("ro.build.version.release")
            if each.serial.hasPrefix("emulator-") {
                let avd = (await ToolOutput.standardOutput(adb, ["-s", each.serial, "emu", "avd", "name"]) ?? "")
                    .split(separator: "\n").first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
                listed.append(Destination(
                    id: each.serial, udid: each.serial, name: avd.isEmpty ? each.model ?? each.serial : avd, kind: .emulator,
                    version: version, booted: true, architecture: Self.architecture(ofABI: abi)))
            } else {
                listed.append(Destination(
                    id: each.serial, udid: each.serial, name: each.model ?? each.serial, kind: .device, version: version,
                    connection: each.usb ? "USB" : each.serial.contains(":") ? "Wi-Fi" : nil, architecture: Self.architecture(ofABI: abi)))
            }
        }
        let running = Set(listed.filter { $0.kind == .emulator }.map(\.name))
        let avds = (await ToolOutput.standardOutput(.path(tools.emulator.path), ["-list-avds"]) ?? "")
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !$0.hasPrefix("INFO") }
        for avd in avds where !running.contains(avd) {
            listed.append(Destination(id: avd, udid: avd, name: avd, kind: .emulator, version: ""))
        }
        return listed
    }

    /// The devices `adb devices -l` printed as attached and ready: each one's serial, model, and whether it is on USB.
    public static func attached(fromADB text: String) -> [(serial: String, model: String?, usb: Bool)] {
        text.split(separator: "\n").dropFirst().compactMap { line in
            let fields = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard fields.count >= 2, fields[1] == "device" else { return nil }
            let model = fields.first { $0.hasPrefix("model:") }.map { String($0.dropFirst("model:".count)) }
            return (fields[0], model, fields.contains { $0.hasPrefix("usb:") })
        }
    }

    /// The architecture of the Android ABI `abi`: `arm64-v8a` is `arm64`.
    public static func architecture(ofABI abi: String) -> Architecture? {
        ["arm64-v8a": .arm64, "x86_64": .x86_64, "armeabi-v7a": .armv7, "x86": .x86][abi]
    }

    /// The Android ABI of `architecture`: `arm64` is `arm64-v8a`.
    public static func abi(of architecture: Architecture) -> String? {
        [.arm64: "arm64-v8a", .x86_64: "x86_64", .armv7: "armeabi-v7a", .x86: "x86"][architecture]
    }

    /// The destination `wanted` names among `listed` - by serial or name, a running one first - else the one
    /// `ANDROID_SERIAL` names, else the only one running.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` where nothing listed is the one named, or none or several run.
    public static func choose(_ wanted: String?, from listed: [Destination], environment: [String: String] = [:]) throws -> Destination {
        let named = wanted.flatMap { $0.isEmpty ? nil : $0 } ?? environment["ANDROID_SERIAL"].flatMap { $0.isEmpty ? nil : $0 }
        if let named {
            let matching = listed.filter { [$0.id, $0.udid, $0.name].contains(named) }
            if let found = matching.first(where: \.booted) ?? matching.first(where: { $0.kind == .device }) ?? matching.first {
                return found
            }
            throw ToolingError(.invalidConfiguration, "No Android device or emulator here is \(named); `stateui devices --host android` lists them.")
        }
        let running = listed.filter { $0.kind == .device || $0.booted }
        guard running.count == 1, let only = running.first else {
            throw ToolingError(.invalidConfiguration, running.isEmpty
                ? "No Android device is attached and no emulator runs: start one, or name a virtual device to boot."
                : "Several Android devices are attached - name one: \(running.map(\.id).joined(separator: ", ")).")
        }
        return only
    }

    /// Boots the virtual device `avd` and answers it, running, once Android says it booted - within four minutes.
    ///
    /// - Throws: ``ToolingError`` `TOOL_FAILED` where it did not boot in time.
    public func boot(_ avd: String, reporter: BuildReporter = BuildReporter()) async throws -> Destination {
        reporter.progress("booting \(avd)")
        let adb = ProcessExecutable.path(tools.adb.path)
        let before = Set(Self.attached(fromADB: await ToolOutput.standardOutput(adb, ["devices", "-l"]) ?? "").map(\.serial))
        // The emulator outlives the run that booted it, as a booted simulator does: it is the machine's, not the run's.
        try DetachedProcess.start(tools.emulator.path, ["-avd", avd, "-no-snapshot-save", "-no-boot-anim"])
        for _ in 0..<120 {
            try await Task.sleep(for: .seconds(2))
            for serial in Self.attached(fromADB: await ToolOutput.standardOutput(adb, ["devices", "-l"]) ?? "").map(\.serial)
                where serial.hasPrefix("emulator-") && !before.contains(serial) {
                let booted = await ToolOutput.standardOutput(adb, ["-s", serial, "shell", "getprop", "sys.boot_completed"])
                if booted?.trimmingCharacters(in: .whitespacesAndNewlines) == "1",
                   let found = await list().first(where: { $0.id == serial }) {
                    return found
                }
            }
        }
        throw ToolingError(.toolFailed, "\(avd) did not boot within four minutes.")
    }
}
