// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The NuGet packages a WinUI head is built and laid out with, pinned here and nowhere else: C++/WinRT, the Windows
/// App SDK's WinUI, Foundation and InteractiveExperiences, and the WebView2 WinUI's nuspec names. A package missing
/// from the machine's NuGet folder is fetched from nuget.org, its SHA-512 checked against the catalog's before a
/// byte of it is unpacked.
/// Design: docs/design/tooling/winui-heads.md#the-packages
struct WinUIPackages: Sendable {
    /// The pins, in the order the projection's stamp lists them.
    static let pins: [(id: String, version: String)] = [
        ("microsoft.windows.cppwinrt", "3.0.260818.1"),
        ("microsoft.windowsappsdk.winui", "1.8.260528001"),
        ("microsoft.windowsappsdk.foundation", "1.8.260527000"),
        ("microsoft.windowsappsdk.interactiveexperiences", "1.8.260525001"),
        ("microsoft.web.webview2", "1.0.3179.45"),
    ]

    /// The Windows App SDK's components whose runtime a self-contained application carries.
    static let components = ["microsoft.windowsappsdk.winui", "microsoft.windowsappsdk.foundation", "microsoft.windowsappsdk.interactiveexperiences"]

    /// The NuGet folder: `NUGET_PACKAGES`, else `.nuget/packages` in the user's profile.
    let root: URL

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        root = environment["NUGET_PACKAGES"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".nuget/packages")
    }

    /// What the projection's stamp holds: each pin, `<id> <version>`, a line each.
    static var stamp: String { pins.map { "\($0.id) \($0.version)" }.joined(separator: "\n") }

    /// The pinned version of package `id`.
    static func version(of id: String) throws -> String {
        guard let pin = pins.first(where: { $0.id == id }) else {
            throw ToolingError(.invalidConfiguration, "No NuGet package \(id) is pinned for WinUI.")
        }
        return pin.version
    }

    /// Package `id`'s folder at its pin, fetched first where it is missing.
    func folder(_ id: String, reporter: BuildReporter = BuildReporter()) async throws -> URL {
        let version = try Self.version(of: id)
        let folder = root.appendingPathComponent(id).appendingPathComponent(version)
        if FileManager.default.fileExists(atPath: folder.appendingPathComponent("\(id).nuspec").path) { return folder }
        reporter.progress("fetching \(id) \(version)")
        let download = FileManager.default.temporaryDirectory.appendingPathComponent("\(id).\(version)-\(UUID().uuidString).nupkg")
        defer { try? FileManager.default.removeItem(at: download) }
        try await ToolStep.run(.name("curl"), ["-fsSL", "-o", download.path,
                                               "https://api.nuget.org/v3-flatcontainer/\(id)/\(version)/\(id).\(version).nupkg"],
                               limit: .seconds(600))
        let expected = try await Self.catalogHash(id: id, version: version)
        guard try Self.sha512(of: download) == expected else {
            throw ToolingError(.toolFailed, "\(id) \(version) does not match nuget.org's catalog; nothing of it was unpacked.")
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try await ToolStep.run(.name("tar"), ["-xf", download.path, "-C", folder.path], limit: .seconds(600))
        return folder
    }

    /// The SHA-512 nuget.org's catalog gives package `id` at `version`, in base64.
    static func catalogHash(id: String, version: String) async throws -> String {
        struct Registration: Decodable { var catalogEntry: String }
        struct Catalog: Decodable { var packageHash: String }
        let registration: Registration = try await json("https://api.nuget.org/v3/registration5-semver1/\(id)/\(version).json")
        let catalog: Catalog = try await json(registration.catalogEntry)
        return catalog.packageHash
    }

    private static func json<Value: Decodable>(_ address: String) async throws -> Value {
        guard let text = await ToolOutput.standardOutput(.name("curl"), ["-fsSL", address]) else {
            throw ToolingError(.toolFailed, "nuget.org did not answer \(address).")
        }
        return try JSONDecoder().decode(Value.self, from: Data(text.utf8))
    }

    /// The SHA-512 of `file`, in base64 - the system's own hash.
    static func sha512(of file: URL) throws -> String {
        try WindowsHash.sha512(Data(contentsOf: file)).base64EncodedString()
    }
}
