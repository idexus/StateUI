// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// An application's WinUI head, laid out self-contained from what SwiftPM built: the program and every library
/// SwiftPM laid beside it, the Windows App SDK's runtime with a manifest registering its classes and
/// `resources.pri`, what each backend among the application's dependencies declares, another architecture's Swift
/// runtime, and the application's `Resources/Images` as they are, since WinUI draws SVG.
/// Design: docs/design/tooling/winui-heads.md#the-head
struct WinUIHead {
    var application: URL
    /// The product SwiftPM built: `GalleryWinUI`.
    var product: String
    /// The folder SwiftPM laid the product and the libraries in.
    var binaries: URL
    var architecture: Architecture
    /// The architecture of the toolchain building it, whose Swift runtime stands on the search path.
    var machine: Architecture
    /// The folders of the application's resolved packages, whose backends contribute.
    var dependencies: [URL]
    var packages: WinUIPackages
    /// The compiler, whose installer's merge modules hold each architecture's Swift runtime.
    var compiler: URL
    /// Where the Swift runtime is unpacked once.
    var cache: URL

    /// What of SwiftPM's folder a head runs with: the program, its libraries and the packages' resources.
    static func carried(_ name: String, product: String) -> Bool {
        name == "\(product).exe" || name.lowercased().hasSuffix(".dll") || name.hasSuffix(".resources")
    }

    /// Lays the head in `staging`.
    func assemble(in staging: URL, reporter: BuildReporter) async throws {
        let files = FileManager.default
        for name in try files.contentsOfDirectory(atPath: binaries.path).sorted() where Self.carried(name, product: product) {
            try files.copyItem(at: binaries.appendingPathComponent(name), to: staging.appendingPathComponent(name))
        }
        try await Self.makeSelfContained(
            staging, executables: ["\(product).exe"], architecture: architecture, machine: machine, dependencies: dependencies,
            packages: packages, compiler: compiler, cache: cache, reporter: reporter)
        let images = application.appendingPathComponent("Resources/Images")
        if files.fileExists(atPath: images.path) {
            try files.copyItem(at: images, to: staging.appendingPathComponent("Images"))
        }
    }

    /// Makes `directory` self-contained for each of `executables`, built for `architecture`: the Windows App SDK's
    /// runtime beside them with a manifest beside each registering its classes, `resources.pri`, what each backend
    /// among `dependencies` declares, and the Swift runtime where `architecture` is not the toolchain's `machine`.
    static func makeSelfContained(
        _ directory: URL, executables: [String], architecture: Architecture, machine: Architecture, dependencies: [URL],
        packages: WinUIPackages, compiler: URL, cache: URL, reporter: BuildReporter
    ) async throws {
        let backends = try BackendRuntime.declared(in: dependencies)
        var fragments: [Data] = []
        for id in WinUIPackages.components {
            let component = try await packages.folder(id, reporter: reporter).appendingPathComponent("runtimes-framework")
            try copyContents(of: component.appendingPathComponent("win-\(BackendRuntime.word(for: architecture))/native"), into: directory)
            fragments.append(try Data(contentsOf: component.appendingPathComponent("package.appxfragment")))
        }
        for backend in backends {
            try await backend.lay(in: directory, architecture: architecture, packages: packages, reporter: reporter)
        }
        if architecture != machine {
            try await SwiftRuntime.lay(in: directory, architecture: architecture, compiler: compiler, cache: cache, reporter: reporter)
        }
        let manifest = Data(try WinUIManifest.text(fragments: fragments).utf8)
        for executable in executables {
            try manifest.write(to: directory.appendingPathComponent("\(executable).manifest"))
        }
        // WinUI's controls find their resources in the application's index.
        let index = directory.appendingPathComponent("resources.pri")
        try? FileManager.default.removeItem(at: index)
        try FileManager.default.copyItem(at: directory.appendingPathComponent("Microsoft.UI.Xaml.Controls.pri"), to: index)
    }

    /// Readies a laid head for a machine with nothing installed: the Swift runtime of its architecture, which the
    /// toolchain's own stood on the search path for, and Visual Studio's C++ runtime, which the Swift runtime links.
    static func readyForDeployment(_ folder: URL, architecture: Architecture, compiler: URL, cache: URL, reporter: BuildReporter) async throws {
        try await SwiftRuntime.lay(in: folder, architecture: architecture, compiler: compiler, cache: cache, reporter: reporter)
        try await CppRuntime.lay(in: folder, architecture: architecture)
    }

    /// Copies `source`'s files into `destination`, folders merged - each component has its own `en-us` - and a file
    /// standing there replaced.
    static func copyContents(of source: URL, into destination: URL) throws {
        let files = FileManager.default
        for name in try files.contentsOfDirectory(atPath: source.path).sorted() {
            let from = source.appendingPathComponent(name)
            let target = destination.appendingPathComponent(name)
            var folder: ObjCBool = false
            if files.fileExists(atPath: from.path, isDirectory: &folder), folder.boolValue {
                try files.createDirectory(at: target, withIntermediateDirectories: true)
                try copyContents(of: from, into: target)
            } else {
                try? files.removeItem(at: target)
                try files.copyItem(at: from, to: target)
            }
        }
    }

    /// The folders of the packages the package at `package` resolved, at every depth - read from SwiftPM's own
    /// `show-dependencies`, written to a file, as its standard output carries its progress too.
    static func resolvedDependencies(
        of package: URL, scratch: [String], compiler: ProcessExecutable, environment: ProcessEnvironment
    ) async throws -> [URL] {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-dependencies-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        try await ToolStep.run(compiler, ["package", "--package-path", package.path] + scratch
                                          + ["show-dependencies", "--format", "json", "--output-path", file.path],
                               environment: environment, limit: .seconds(300))
        do {
            return try dependencies(in: try Data(contentsOf: file))
        } catch {
            throw ToolingError(.toolFailed, "SwiftPM's dependencies of \(package.lastPathComponent) are not read: \(error)")
        }
    }

    /// The folders of the packages `json` - `swift package show-dependencies --format json` - lists, at every depth.
    static func dependencies(in json: Data) throws -> [URL] {
        struct Package: Decodable {
            var path: String?
            var dependencies: [Package]?
        }
        func folders(_ package: Package) -> [String] {
            (package.path.map { [$0] } ?? []) + (package.dependencies ?? []).flatMap(folders)
        }
        let root = try JSONDecoder().decode(Package.self, from: json)
        return Array(Set((root.dependencies ?? []).flatMap(folders))).sorted().map { URL(fileURLWithPath: $0) }
    }
}

/// Visual Studio's app-local C++ runtime, which the Swift runtime links: the newest MSVC redistributable's
/// `Microsoft.VC*.CRT` for the architecture, found through `vswhere`.
enum CppRuntime {
    static func lay(in folder: URL, architecture: Architecture) async throws {
        let programs = ProcessInfo.processInfo.environment["ProgramFiles(x86)"] ?? "C:\\Program Files (x86)"
        let vswhere = URL(fileURLWithPath: programs).appendingPathComponent("Microsoft Visual Studio/Installer/vswhere.exe")
        guard let studio = await ToolOutput.text(.path(vswhere.path), ["-latest", "-products", "*", "-property", "installationPath"])?
            .trimmingCharacters(in: .whitespacesAndNewlines), !studio.isEmpty
        else { throw ToolingError(.missingToolchain, "No Visual Studio with its C++ tools is installed: vswhere finds none.") }
        let redistributables = URL(fileURLWithPath: studio).appendingPathComponent("VC/Redist/MSVC")
        let files = FileManager.default
        let releases = ((try? files.contentsOfDirectory(atPath: redistributables.path)) ?? [])
            .filter { $0.split(separator: ".").count == 3 && $0.split(separator: ".").allSatisfy { Int($0) != nil } }
            .sorted { $0.split(separator: ".").compactMap { Int($0) }.lexicographicallyPrecedes($1.split(separator: ".").compactMap { Int($0) }) }
        let word = BackendRuntime.word(for: architecture)
        guard let release = releases.last.map({ redistributables.appendingPathComponent($0).appendingPathComponent(word) }),
              let runtime = ((try? files.contentsOfDirectory(atPath: release.path)) ?? []).sorted()
                .first(where: { $0.hasPrefix("Microsoft.VC") && $0.hasSuffix(".CRT") })
        else { throw ToolingError(.missingToolchain, "Visual Studio holds no C++ runtime for \(word) in \(redistributables.path).") }
        let crt = release.appendingPathComponent(runtime)
        for name in try files.contentsOfDirectory(atPath: crt.path).sorted() where name.lowercased().hasSuffix(".dll") {
            try? files.removeItem(at: folder.appendingPathComponent(name))
            try files.copyItem(at: crt.appendingPathComponent(name), to: folder.appendingPathComponent(name))
        }
    }
}
