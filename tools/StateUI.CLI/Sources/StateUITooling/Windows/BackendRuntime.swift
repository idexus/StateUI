// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// What a WinUI backend lays beside an application linking it, as its `Packaging/runtime.txt` declares: a line a
/// file, `<package> <path in the package> <path beside the application>`, `{architecture}` in the package's path
/// standing for Windows' word for the architecture built for (`arm64`, `x64`), `#` a comment. The package is one the
/// tool pins; only a backend among the application's dependencies contributes.
/// Design: docs/design/tooling/winui-heads.md#a-backends-runtime
struct BackendRuntime: Equatable, Sendable {
    struct File: Equatable, Sendable {
        var package: String
        var source: String
        var destination: String
    }

    /// The backend's folder name: `WebView.WinUI`.
    var backend: String
    var files: [File]

    /// Where a backend declares it, in its package's folder.
    static let declaration = "Packaging/runtime.txt"

    /// The declaration `text` of `backend`; a line that is not three words, a package not pinned, or a path leaving
    /// its root is `INVALID_CONFIGURATION`.
    static func parse(_ text: String, backend: String) throws -> BackendRuntime {
        var files: [File] = []
        for (number, line) in text.split(whereSeparator: \.isNewline).enumerated() {
            let words = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            if words.isEmpty || words[0].hasPrefix("#") { continue }
            let place = "\(backend)'s \(declaration), line \(number + 1)"
            guard words.count == 3 else {
                throw ToolingError(.invalidConfiguration, "\(place) names a package, a path in it and a path beside the application.")
            }
            guard WinUIPackages.pins.contains(where: { $0.id == words[0] }) else {
                throw ToolingError(.invalidConfiguration, "\(place): no NuGet package \(words[0]) is pinned for WinUI.")
            }
            for path in words[1...] where !isInside(path) {
                throw ToolingError(.invalidConfiguration, "\(place): \(path) leaves its folder.")
            }
            guard !words[2].contains("{") else {
                throw ToolingError(.invalidConfiguration, "\(place): a path beside the application names no architecture.")
            }
            files.append(File(package: words[0], source: words[1], destination: words[2]))
        }
        return BackendRuntime(backend: backend, files: files)
    }

    /// Whether `path` stays inside the folder it is read against: relative, with no `..`.
    static func isInside(_ path: String) -> Bool {
        let parts = path.split(whereSeparator: { $0 == "/" || $0 == "\\" })
        return !path.hasPrefix("/") && !path.hasPrefix("\\") && !path.contains(":") && !parts.isEmpty && !parts.contains("..")
    }

    /// The declarations of the backends among `dependencies` - the folders of an application's resolved packages -
    /// checked together: two sources for one destination fail before anything is laid.
    static func declared(in dependencies: [URL]) throws -> [BackendRuntime] {
        let runtimes = try dependencies.sorted { $0.path < $1.path }.compactMap { folder -> BackendRuntime? in
            let file = folder.appendingPathComponent(declaration)
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
            return try parse(text, backend: folder.lastPathComponent)
        }
        try check(runtimes)
        return runtimes
    }

    /// Refuses two different sources for one destination, Windows' names compared as Windows does, regardless of case.
    static func check(_ runtimes: [BackendRuntime]) throws {
        var laid: [String: (backend: String, file: File)] = [:]
        for runtime in runtimes {
            for file in runtime.files {
                let key = file.destination.lowercased().replacingOccurrences(of: "\\", with: "/")
                if let before = laid[key], before.file.package != file.package || before.file.source != file.source {
                    throw ToolingError(.invalidConfiguration,
                        "\(before.backend) and \(runtime.backend) both lay \(file.destination) beside the application, from different files.")
                }
                laid[key] = (runtime.backend, file)
            }
        }
    }

    /// Windows' word for `architecture` in a package's paths.
    static func word(for architecture: Architecture) -> String {
        architecture == .x86_64 ? "x64" : architecture.rawValue
    }

    /// Lays the files beside the application in `directory`, built for `architecture`, from `packages`.
    func lay(in directory: URL, architecture: Architecture, packages: WinUIPackages, reporter: BuildReporter) async throws {
        for file in files {
            let package = try await packages.folder(file.package, reporter: reporter)
            let source = package.appendingPathComponent(file.source.replacingOccurrences(of: "{architecture}", with: Self.word(for: architecture)))
            let destination = directory.appendingPathComponent(file.destination)
            guard FileManager.default.fileExists(atPath: source.path) else {
                throw ToolingError(.toolFailed, "\(backend) lays \(file.source) of \(file.package), which has no such file for \(architecture.rawValue).")
            }
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: source, to: destination)
        }
    }
}
