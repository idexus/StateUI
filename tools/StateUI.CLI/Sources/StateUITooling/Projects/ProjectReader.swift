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

    /// The project at `path`: the nearest application up from it, else the applications its workspace - the nearest
    /// `stateui.json` up - lists.
    ///
    /// - Throws: ``ToolingError`` - `PROJECT_NOT_FOUND`, `INVALID_CONFIGURATION`, `MISSING_TOOLCHAIN`, `TOOL_FAILED` -
    ///   or `CancellationError`.
    public func describe(containing path: URL) async throws -> Project {
        let folder = RealPath.of(RealPath.lexical(path))
        let workspace = try Workspace.nearest(from: folder)
        if let application = Self.application(holding: folder) {
            return try await describe(root: application, packages: [application], workspace: workspace, startup: nil)
        }
        guard let workspace else {
            throw ToolingError(
                .projectNotFound, "No StateUI application stands in or above \(path.path), and no stateui.json lists one.")
        }
        return try await describe(
            root: workspace.folder, packages: try workspace.applications(), workspace: workspace, startup: try workspace.startup())
    }

    private func describe(root: URL, packages: [URL], workspace: Workspace?, startup: URL?) async throws -> Project {
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
        return Project(
            rootUri: FileURI.string(root), applications: applications.map(\.0), libraries: libraries,
            workspaceUri: workspace.map { FileURI.string($0.folder) }, startupUri: startup.map(FileURI.string))
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

    /// The application `folder` stands in: itself, or the nearest folder above it that is one.
    static func application(holding folder: URL) -> URL? {
        var current = folder
        while true {
            if !hosts(of: current).isEmpty { return current }
            guard let parent = Folders.parent(of: current) else { return nil }
            current = parent
        }
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
        let (inner, outer) = (RealPath.lexical(package).pathComponents, RealPath.lexical(root).pathComponents)
        guard inner.starts(with: outer), inner.count > outer.count else { return "." }
        return inner.dropFirst(outer.count).joined(separator: "/")
    }
}
