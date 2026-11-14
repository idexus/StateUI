// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if canImport(AppKit)
import AppKit
#endif
import Foundation
import StateUIToolingProtocol

/// The browsers installed here, a Web head's destinations - what the system opens both a web address and a web page
/// with - and a page opened in one.
/// Design: docs/design/tooling/destinations.md#browsers
enum Browsers {
    /// The browsers, the system's own marked as booted: on macOS every application Launch Services lists for https and
    /// for an HTML file, by its bundle id; on Linux every desktop entry taking both, by its file's name.
    static func list() async -> [Destination] {
        #if canImport(AppKit)
        let workspace = NSWorkspace.shared
        let address = URL(string: "https://example.com")!
        let page = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-browsers-\(UUID().uuidString).html")
        try? Data("<html></html>".utf8).write(to: page)
        defer { try? FileManager.default.removeItem(at: page) }
        let pages = Set(workspace.urlsForApplications(toOpen: page).compactMap { Bundle(url: $0)?.bundleIdentifier })
        let preferred = workspace.urlForApplication(toOpen: address)
        var seen = Set<String>()
        return workspace.urlsForApplications(toOpen: address).compactMap { application in
            guard let id = Bundle(url: application)?.bundleIdentifier, pages.contains(id), seen.insert(id).inserted else { return nil }
            let name = FileManager.default.displayName(atPath: application.path).replacingOccurrences(of: ".app", with: "")
            return Destination(id: id, udid: id, name: name, kind: .browser, version: "", booted: application == preferred)
        }
        #else
        let home = FileManager.default.homeDirectoryForCurrentUser
        let data = ProcessInfo.processInfo.environment["XDG_DATA_HOME"].map { URL(fileURLWithPath: $0) } ?? home.appendingPathComponent(".local/share")
        let folders = [data.appendingPathComponent("applications"), URL(fileURLWithPath: "/usr/local/share/applications"),
                       URL(fileURLWithPath: "/usr/share/applications"), URL(fileURLWithPath: "/var/lib/flatpak/exports/share/applications"),
                       URL(fileURLWithPath: "/var/lib/snapd/desktop/applications")]
        let preferred = (await ToolOutput.standardOutput(.name("xdg-settings"), ["get", "default-web-browser"]) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<String>()
        var found: [Destination] = []
        for folder in folders {
            for id in ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted() where id.hasSuffix(".desktop") {
                guard let entry = try? String(contentsOf: folder.appendingPathComponent(id), encoding: .utf8),
                      let name = Self.browser(entry), seen.insert(id).inserted
                else { continue }
                found.append(Destination(id: id, udid: id, name: name, kind: .browser, version: "", booted: id == preferred))
            }
        }
        return found
        #endif
    }

    /// The name of the browser a desktop entry `text` is - one taking both https and HTML, shown - or `nil`.
    static func browser(_ text: String) -> String? {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        let types = lines.first { $0.hasPrefix("MimeType=") } ?? ""
        guard types.contains("x-scheme-handler/https"), types.contains("text/html"), !lines.contains("NoDisplay=true") else { return nil }
        return lines.first { $0.hasPrefix("Name=") }.map { String($0.dropFirst("Name=".count)) } ?? ""
    }

    /// Opens `url` in browser `id`: `default` the system's own.
    static func open(_ url: String, in id: String) async {
        #if os(macOS)
        await ToolStep.regardless(.name("open"), id == "default" ? [url] : ["-b", id, url])
        #else
        if id == "default" {
            await ToolStep.regardless(.name("xdg-open"), [url])
        } else {
            await ToolStep.regardless(.name("gtk-launch"), [String(id.dropLast(id.hasSuffix(".desktop") ? 8 : 0)), url])
        }
        #endif
    }
}
