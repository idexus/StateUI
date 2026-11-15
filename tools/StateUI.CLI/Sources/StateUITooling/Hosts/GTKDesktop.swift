// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The desktop entry and icon a GTK head is shown by - its name, its icon in the dash, the links it opens - written
/// for the user, where the desktop reads them.
/// Design: docs/design/tooling/gtk-heads.md#installing
struct GTKDesktop {
    /// The user's data folder: `XDG_DATA_HOME`, else `~/.local/share`.
    var data: URL

    /// The data folder `environment` names, else the one under `home`.
    init(environment: [String: String], home: URL) {
        data = environment["XDG_DATA_HOME"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
            ?? home.appendingPathComponent(".local/share")
    }

    /// The entry of `name`'s head - program `program`, run as `product` and known as `identifier` - opening `schemes`.
    static func entry(name: String, program: URL, product: String, identifier: String, schemes: [String]) -> String {
        let types = schemes.map { "x-scheme-handler/\($0);" }.joined()
        return """
            [Desktop Entry]
            Type=Application
            Name=\(name)
            Exec=\(program.path) %u
            Icon=\(identifier)
            StartupWMClass=\(product)
            Terminal=false
            Categories=Development;
            \(types.isEmpty ? "" : "MimeType=\(types)\n")
            """
    }

    /// Writes the entry and copies `icon` beside the desktop's own, then makes the entry each of `schemes`'s default;
    /// answers the files written.
    func register(name: String, program: URL, product: String, identifier: String, icon: URL, schemes: [String]) async throws -> [URL] {
        let files = FileManager.default
        let icons = data.appendingPathComponent("icons/hicolor/scalable/apps")
        let applications = data.appendingPathComponent("applications")
        try files.createDirectory(at: icons, withIntermediateDirectories: true)
        try files.createDirectory(at: applications, withIntermediateDirectories: true)
        let iconFile = icons.appendingPathComponent("\(identifier).svg")
        try? files.removeItem(at: iconFile)
        try files.copyItem(at: icon, to: iconFile)
        let entry = applications.appendingPathComponent("\(identifier).desktop")
        try Data(Self.entry(name: name, program: program, product: product, identifier: identifier, schemes: schemes).utf8).write(to: entry)
        for scheme in schemes {
            await ToolStep.regardless(.name("xdg-mime"), ["default", "\(identifier).desktop", "x-scheme-handler/\(scheme)"])
        }
        return [entry, iconFile]
    }

    /// The link schemes `Platforms/GTK/link-schemes` of `application` lists, one a line.
    static func schemes(of application: URL) -> [String] {
        let text = (try? String(contentsOf: application.appendingPathComponent("Platforms/GTK/link-schemes"), encoding: .utf8)) ?? ""
        return text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
