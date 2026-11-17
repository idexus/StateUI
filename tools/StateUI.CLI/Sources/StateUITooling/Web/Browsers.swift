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
            let program = Bundle(url: application)?.executableURL
            return Destination(id: id, udid: id, name: name, kind: .browser, version: "", booted: application == preferred,
                               debugger: Self.chromium(id) && program != nil, programUri: program.map(FileURI.string))
        }
        #else
        let home = FileManager.default.homeDirectoryForCurrentUser
        let data = ProcessInfo.processInfo.environment["XDG_DATA_HOME"].map { URL(fileURLWithPath: $0) } ?? home.appendingPathComponent(".local/share")
        let folders = [data.appendingPathComponent("applications"), URL(fileURLWithPath: "/usr/local/share/applications"),
                       URL(fileURLWithPath: "/usr/share/applications"), URL(fileURLWithPath: "/var/lib/flatpak/exports/share/applications"),
                       URL(fileURLWithPath: "/var/lib/snapd/desktop/applications")]
        let preferred = (await ToolOutput.standardOutput(.name("xdg-settings"), ["get", "default-web-browser"]) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let desktops = (ProcessInfo.processInfo.environment["XDG_CURRENT_DESKTOP"] ?? "").split(separator: ":").map(String.init)
        var seen = Set<String>()
        var found: [Destination] = []
        for folder in folders {
            for id in ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted() where id.hasSuffix(".desktop") {
                guard let entry = try? String(contentsOf: folder.appendingPathComponent(id), encoding: .utf8),
                      let browser = Self.browser(entry, on: desktops), seen.insert(id).inserted
                else { continue }
                let program = browser.program.hasPrefix("/") ? URL(fileURLWithPath: browser.program) : SearchPath().find(browser.program)
                found.append(Destination(id: id, udid: id, name: browser.name, kind: .browser, version: "", booted: id == preferred,
                                         debugger: Self.chromium(id) && program != nil, programUri: program.map(FileURI.string)))
            }
        }
        return found
        #endif
    }

    /// Whether the browser `id` names is one of Chromium's - Chrome, Chromium, Edge, Brave, Vivaldi, Opera, Arc - whose
    /// pages a debugger follows over its debugging protocol.
    static func chromium(_ id: String) -> Bool {
        let lowered = id.lowercased()
        return ["chrome", "chromium", "edge", "brave", "vivaldi", "opera", "thebrowser"].contains { lowered.contains($0) }
    }

    /// The browser a desktop entry `text` is - one taking both https and HTML, shown on `desktops` - by its name and
    /// the program its `Exec` starts, or `nil`.
    static func browser(_ text: String, on desktops: [String]) -> (name: String, program: String)? {
        let entry = text.split(whereSeparator: \.isNewline).map(String.init)
            .drop { $0 != "[Desktop Entry]" }.dropFirst().prefix { !$0.hasPrefix("[") }
        func value(_ key: String) -> String? { entry.first { $0.hasPrefix(key + "=") }.map { String($0.dropFirst(key.count + 1)) } }
        func list(_ key: String) -> [String] { (value(key) ?? "").split(separator: ";").map(String.init) }
        let types = list("MimeType")
        guard types.contains("x-scheme-handler/https"), types.contains("text/html"), value("NoDisplay") != "true",
              value("Hidden") != "true", value("OnlyShowIn") == nil || list("OnlyShowIn").contains(where: desktops.contains),
              !list("NotShowIn").contains(where: desktops.contains), let program = Self.program(value("Exec") ?? "")
        else { return nil }
        return (value("Name") ?? "", program)
    }

    /// The program an `Exec` line starts: its first word - quoted where it holds a space - past `env` and its
    /// variables.
    static func program(_ exec: String) -> String? {
        var words: [String] = []
        var word: String?
        var quoted = false
        for character in exec {
            if character == "\"" {
                quoted.toggle()
                word = word ?? ""
            } else if character == " ", !quoted {
                word.map { words.append($0) }
                word = nil
            } else {
                word = (word ?? "") + String(character)
            }
        }
        word.map { words.append($0) }
        if words.first == "env" { words = Array(words.dropFirst().drop { $0.contains("=") }) }
        return words.first
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
