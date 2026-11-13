// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// Projects read off the disk and SwiftPM: which folders hold applications, what each declares, and the StateUI each
/// builds with.
/// Design: docs/design/tooling/projects.md#a-project-read
public struct ProjectReader: Sendable {
    private let runner = ProcessRunner()
    private let tools: ToolResolver

    /// A reader finding its programs through `tools`.
    public init(tools: ToolResolver = ToolResolver()) {
        self.tools = tools
    }

    /// The project holding `path`: the nearest folder from it up that is an application or keeps applications in
    /// `apps/`.
    ///
    /// - Throws: ``ToolingError`` - `PROJECT_NOT_FOUND`, `MISSING_TOOLCHAIN`, `TOOL_FAILED` - or `CancellationError`.
    public func describe(containing path: URL) async throws -> Project {
        var folder = path.standardizedFileURL.resolvingSymlinksInPath()
        while true {
            let packages = Self.applicationFolders(in: folder)
            if !packages.isEmpty { return try await describe(root: folder, packages: packages) }
            let parent = folder.deletingLastPathComponent().standardizedFileURL
            let (above, here) = (parent.pathComponents, folder.pathComponents)
            if above.count >= here.count || Array(here.prefix(above.count)) != above {
                throw ToolingError(.projectNotFound, "No StateUI application stands in or above \(path.path).")
            }
            folder = parent
        }
    }

    private func describe(root: URL, packages: [URL]) async throws -> Project {
        let applications = try await withThrowingTaskGroup(of: (Application, Checkout?).self) { group in
            for package in packages {
                group.addTask { try await self.application(at: package, root: root) }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }.sorted { $0.0.id < $1.0.id }
        var checkouts: [String: Checkout] = [:]
        for case let checkout? in applications.map(\.1) where checkouts[checkout.root.path] == nil {
            checkouts[checkout.root.path] = checkout
        }
        var libraries: [Library] = []
        for path in checkouts.keys.sorted() {
            libraries.append(await checkouts[path]!.library(runner: runner, tools: tools))
        }
        try Task.checkCancellation()
        return Project(rootUri: FileURI.string(root), applications: applications.map(\.0), libraries: libraries)
    }

    private func application(at package: URL, root: URL) async throws -> (Application, Checkout?) {
        let description = try await describePackage(package)
        let checkout = description.dependencies.lazy.compactMap { $0.path.flatMap { Checkout(at: URL(fileURLWithPath: $0)) } }
            .first
        let application = Application(
            id: Self.relativePath(of: package, from: root),
            name: package.lastPathComponent,
            packageUri: FileURI.string(package),
            declaredHosts: Self.hosts(of: package),
            products: description.products.map(\.name).sorted(),
            testSuites: description.targets.filter { $0.type == "test" }.map(\.name).sorted(),
            libraryUri: checkout.map { FileURI.string($0.root) })
        return (application, checkout)
    }

    /// Design: docs/design/tooling/projects.md#swiftpm-reads-a-package-without-a-host
    private func describePackage(_ package: URL) async throws -> PackageDescription {
        let output = Gathered()
        let request = ProcessRequest(
            tools.swift, arguments: ["package", "describe", "--type", "json"],
            environment: ProcessEnvironment.inherited.removing("STATEUI_HOST"),
            workingDirectory: package.path, timeout: .seconds(300))
        let outcome: ProcessOutcome
        do {
            outcome = try await runner.run(request, output: output.add)
        } catch ProcessFailure.notFound(let reason) {
            throw ToolingError(.missingToolchain, "Swift cannot be found: \(reason) Put it on the search path, or name it in SWIFT_BIN.")
        }
        try Task.checkCancellation()
        guard outcome.succeeded else {
            let said = output.lines(of: .standardError).suffix(5).joined(separator: "\n")
            throw ToolingError(.toolFailed, "SwiftPM cannot read \(package.path):\n\(said)")
        }
        let json = Data(output.lines(of: .standardOutput).joined(separator: "\n").utf8)
        do {
            return try JSONDecoder().decode(PackageDescription.self, from: json)
        } catch {
            throw ToolingError(.toolFailed, "SwiftPM described \(package.path) in words the tool cannot read: \(error)")
        }
    }

    /// The folders holding an application: `folder` itself, and each folder of its `apps/`.
    static func applicationFolders(in folder: URL) -> [URL] {
        let apps = folder.appendingPathComponent("apps")
        let children = ((try? FileManager.default.contentsOfDirectory(atPath: apps.path)) ?? []).sorted()
            .map { apps.appendingPathComponent($0) }
        return ([folder] + children).filter { !hosts(of: $0).isEmpty }
    }

    /// The hosts a package has a head for: a `main.swift` in `Platforms/<Host>`, or Android's Gradle build there.
    static func hosts(of package: URL) -> [HostFamily] {
        let files = FileManager.default
        guard files.fileExists(atPath: package.appendingPathComponent("Package.swift").path) else { return [] }
        return HostFamily.allCases.filter { host in
            let head = package.appendingPathComponent("Platforms").appendingPathComponent(host.folder)
            let file = host == .android ? "build.gradle.kts" : "main.swift"
            return files.fileExists(atPath: head.appendingPathComponent(file).path)
        }
    }

    private static func relativePath(of package: URL, from root: URL) -> String {
        let (inner, outer) = (package.standardizedFileURL.pathComponents, root.standardizedFileURL.pathComponents)
        guard inner.starts(with: outer), inner.count > outer.count else { return "." }
        return inner.dropFirst(outer.count).joined(separator: "/")
    }
}
