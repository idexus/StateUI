// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// What platform tools print, read for the one fact a check asks of each.
public enum ToolText {
    /// Xcode's version in `xcodebuild -version`'s output: `27.0` in `Xcode 27.0`.
    public static func xcodeVersion(in text: String) -> String? {
        text.firstMatch(of: /Xcode (\d+(?:\.\d+)*)/).map { String($0.output.1) }
    }

    /// The newest available iOS simulator runtime `xcrun simctl list runtimes available -j` lists, by its version.
    public static func newestIOSRuntime(in json: String) -> String? {
        struct Runtimes: Decodable {
            struct Runtime: Decodable { var platform: String?; var name: String?; var version: String?; var isAvailable: Bool? }
            var runtimes: [Runtime]?
        }
        guard let read = try? JSONDecoder().decode(Runtimes.self, from: Data(json.utf8)) else { return nil }
        return (read.runtimes ?? [])
            .filter { ($0.platform == "iOS" || $0.name?.hasPrefix("iOS") == true) && $0.isAvailable != false }
            .compactMap { $0.version.flatMap { $0.isEmpty ? nil : $0 } }
            .sorted { Versions.compare($0, $1) < 0 }.last
    }

    /// The first Apple Development identity `security find-identity -v -p codesigning` lists, by its name.
    public static func developmentIdentity(in text: String) -> String? {
        text.firstMatch(of: /"(Apple Development: [^"]+)"/).map { String($0.output.1) }
    }

    /// An NDK's release in its `source.properties`: `30.0.16248370`.
    public static func ndkRevision(in properties: String) -> String? {
        properties.firstMatch(of: /(?m)^Pkg\.Revision\s*=\s*(\S+)/).map { String($0.output.1) }
    }

    /// The file of the loader a gdk-pixbuf loaders cache names for SVG pictures.
    public static func svgLoader(inCache cache: String) -> String? {
        for entry in cache.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n\n") {
            let lines = entry.split(separator: "\n").map(String.init).filter { !$0.isEmpty && !$0.hasPrefix("#") }
            guard lines.count > 1, lines.contains(where: { $0.contains(/(^|\s)"image\/svg\+xml"(\s|$)/) }) else { continue }
            let file = lines[0].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            return URL(fileURLWithPath: file).lastPathComponent
        }
        return nil
    }

    /// The loader a glycin loader's config names for SVG pictures - its `[loader:image/svg+xml]` section's `Exec`.
    public static func svgLoader(inGlycinConfig config: String) -> String? {
        var inSection = false
        for line in config.split(whereSeparator: \.isNewline).map({ $0.trimmingCharacters(in: .whitespaces) }) {
            if line.hasPrefix("[") { inSection = line.hasPrefix("[loader:image/svg+xml]"); continue }
            guard inSection, let match = line.firstMatch(of: /^Exec\s*=\s*(.+?)\s*$/) else { continue }
            return URL(fileURLWithPath: String(match.output.1)).lastPathComponent
        }
        return nil
    }
}
