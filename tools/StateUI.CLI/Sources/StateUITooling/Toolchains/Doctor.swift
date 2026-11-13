// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// What this machine needs to build and run the hosts it can, as the handbook's requirements say: each component
/// looked for, read-only, and where it is missing, what to install.
/// Design: docs/design/tooling/doctor.md#what-doctor-checks
public struct Doctor: Sendable {
    /// What a look found: the component, a version too old, or nothing.
    enum Look: Sendable {
        case found(String)
        case tooOld(String)
        case missing
    }

    struct Check: Sendable {
        var component: String
        var neededBy: String
        var hosts: [HostFamily]
        var advice: String
        var look: @Sendable () async -> Look
    }

    /// The oldest release of Apple's systems StateUI runs on - iOS, Mac Catalyst and macOS alike.
    static let appleFloor = "26.4"

    private let tools: ToolResolver
    private let path: SearchPath
    private let environment: [String: String]

    /// A doctor reading this process's environment.
    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
        tools = ToolResolver(environment: environment)
        path = SearchPath(environment: environment)
    }

    /// Every component this machine needs, each looked for at once and told in the checks' order.
    public func check() async -> ToolchainReport {
        let checks = self.checks()
        let looks = await withTaskGroup(of: (Int, Look).self) { group in
            for (index, check) in checks.enumerated() { group.addTask { (index, await check.look()) } }
            return await group.reduce(into: [Int: Look]()) { $0[$1.0] = $1.1 }
        }
        return ToolchainReport(findings: checks.enumerated().map { index, check in
            let look = looks[index] ?? .missing
            var found: String?, tooOld: String?
            switch look {
            case .found(let what): found = what
            case .tooOld(let version): tooOld = version
            case .missing: break
            }
            return ToolFinding(
                component: check.component, neededBy: check.neededBy, hosts: check.hosts, found: found, tooOld: tooOld,
                advice: check.advice)
        })
    }

    func checks() -> [Check] {
        #if os(macOS)
        let own = macChecks() + webChecks()
        #elseif os(Linux)
        let own = linuxChecks() + webChecks()
        #elseif os(Windows)
        let own = windowsChecks()
        #else
        let own: [Check] = []
        #endif
        return [swiftCheck()] + own + [lldbDapCheck(), gitCheck(), nodeCheck()]
    }

    /// A version found where it is `minimum` or newer, said with where it stands; one older, as too old.
    static func served(_ version: String?, _ minimum: String, at place: String? = nil) -> Look {
        guard let version else { return .missing }
        guard Versions.atLeast(version, minimum) else { return .tooOld(version) }
        return .found(place.map { "\(version) (\($0))" } ?? version)
    }

    static func present(_ what: String?) -> Look { what.map(Look.found) ?? .missing }

    private func swiftCheck() -> Check {
        let (tools, path) = (tools, path)
        return Check(
            component: "Swift 6.4 or newer", neededBy: "every host", hosts: HostFamily.allCases,
            advice: "Install Swift 6.4 from https://www.swift.org/install (on macOS, Xcode 27 brings it).") {
                let text = await ToolOutput.text(tools.swift, ["--version"])
                let place: String? = if case .path(let named) = tools.swift { named } else { path.find("swift")?.path }
                return Self.served(text.flatMap { Versions.swiftRelease(in: $0) }, "6.4", at: place)
            }
    }

    private func lldbDapCheck() -> Check {
        let path = path
        return Check(
            component: "lldb-dap", neededBy: "Debug", hosts: [],
            advice: "It comes with the Swift toolchain; put the toolchain's bin directory on the search path.") {
                #if os(macOS)
                let found = await ToolOutput.text(.name("xcrun"), ["--find", "lldb-dap"])?
                    .split(separator: "\n").last.map(String.init)
                return Self.present(found)
                #else
                let name = "lldb-dap"
                if let swift = path.find("swift")?.resolvingSymlinksInPath() {
                    #if os(Windows)
                    let beside = swift.deletingLastPathComponent().appendingPathComponent(name + ".exe")
                    #else
                    let beside = swift.deletingLastPathComponent().appendingPathComponent(name)
                    #endif
                    if FileManager.default.fileExists(atPath: beside.path) { return .found(beside.path) }
                }
                return Self.present(path.find(name)?.path)
                #endif
            }
    }

    private func gitCheck() -> Check {
        let (tools, path) = (tools, path)
        return Check(
            component: "Git", neededBy: "a new project's releases", hosts: [],
            advice: "Install Git from https://git-scm.com.") {
                let version = await ToolOutput.text(tools.git, ["--version"]).flatMap { Versions.first(in: $0) }
                return Self.present(version.map { "\($0) (\(path.find("git")?.path ?? "git"))" })
            }
    }

    private func nodeCheck() -> Check {
        let path = path
        return Check(
            component: "Node.js 20 or newer, with npm", neededBy: "the editor extension's own build", hosts: [],
            advice: "Install Node.js 20 or newer from https://nodejs.org.") {
                guard path.find("npm") != nil else { return .missing }
                let version = await ToolOutput.text(.name("node"), ["--version"])?
                    .trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "v", with: "")
                return Self.served(version.flatMap { Versions.first(in: $0) }, "20")
            }
    }

    private func webChecks() -> [Check] {
        let (tools, path) = (tools, path)
        return [
            Check(
                component: "the Swift SDK for WebAssembly of Swift's release", neededBy: "Web", hosts: [.web],
                advice: "Install it with `swift sdk install`: https://www.swift.org/documentation/articles/wasm-getting-started.html") {
                    let release = await ToolOutput.text(tools.swift, ["--version"]).flatMap { Versions.swiftRelease(in: $0) }
                    let list = await ToolOutput.text(tools.swift, ["sdk", "list"]) ?? ""
                    return Self.present(Versions.swiftSDK(of: release, in: list, family: "wasm"))
                },
            Check(
                component: "Python 3", neededBy: "Web, which serves its page with it", hosts: [.web],
                advice: "Install Python 3: macOS's comes with Xcode's command line tools; on Linux, the distribution's python3.") {
                    guard path.find("python3") != nil else { return .missing }
                    return Self.present(await ToolOutput.text(.name("python3"), ["--version"]).flatMap { Versions.first(in: $0) })
                },
        ]
    }
}
