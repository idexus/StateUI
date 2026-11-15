// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// What an editor's language server indexes each host's code with, decided once here: a host's own scratch folder,
/// and for a host whose heads run elsewhere the triple and SDK its builds take - the simulator's for UIKit, the Swift
/// SDK of the compiler's release for Android and the Web - else this machine's, with why.
/// Design: docs/design/tooling/indexing.md
struct IndexContexts: Sendable {
    let tools: ToolResolver

    /// The scratch folder of the code indexed as `host`, or as plain Swift.
    static func scratchPath(of host: HostFamily?) -> String {
        host.map { ".build/\($0.rawValue)/index-build" } ?? ".build/index-build"
    }

    /// Every scratch folder an index stands in.
    static var scratchPaths: [String] { HostFamily.allCases.map { scratchPath(of: $0) } + [scratchPath(of: nil)] }

    /// The context of `host`.
    func describe(_ host: HostFamily?) async -> IndexContext {
        let scratch = Self.scratchPath(of: host)
        switch host {
        case .uikit:
            #if os(macOS)
            guard let sdk = await AppleSDK.find(.iOSSimulator) else {
                return IndexContext(host: host, scratchPath: scratch, fallback: "Xcode's iOS simulator SDK was not found")
            }
            let machine = Architecture(rawValue: Machine.current.architecture) ?? .arm64
            return IndexContext(host: host, scratchPath: scratch, triple: AppleSDK.Platform.iOSSimulator.triple(machine, floor: Doctor.appleFloor), sdk: sdk.path)
            #else
            return IndexContext(host: host, scratchPath: scratch, fallback: "UIKit is indexed on a Mac")
            #endif
        case .android:
            return await swiftSDK(host, family: "android", triple: "aarch64-unknown-linux-android28", scratch: scratch)
        case .web:
            return await swiftSDK(host, family: "wasm", triple: "wasm32-unknown-wasip1", scratch: scratch)
        default:
            return IndexContext(host: host, scratchPath: scratch)
        }
    }

    /// A host compiled with the Swift SDK of `family` of the compiler's release.
    private func swiftSDK(_ host: HostFamily?, family: String, triple: String, scratch: String) async -> IndexContext {
        let version = await ToolOutput.text(tools.swift, ["--version"]) ?? ""
        let release = Versions.swiftRelease(in: version)
        let list = await ToolOutput.standardOutput(tools.swift, ["sdk", "list"]) ?? ""
        guard let sdk = Versions.swiftSDK(of: release, in: list, family: family) else {
            return IndexContext(host: host, scratchPath: scratch,
                                fallback: "no Swift SDK for \(host?.folder ?? family) of \(release.map { "Swift \($0)" } ?? "this compiler's release") is installed")
        }
        return IndexContext(host: host, scratchPath: scratch, triple: triple, swiftSDK: sdk)
    }

    /// Takes every index's scratch folder away from `roots`.
    static func clean(_ roots: [URL]) -> [URL] {
        let files = FileManager.default
        return roots.flatMap { root in scratchPaths.map { root.appendingPathComponent($0) } }
            .filter { files.fileExists(atPath: $0.path) && (try? files.removeItem(at: $0)) != nil }
    }
}
