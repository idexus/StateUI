// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

extension Doctor {
    /// What the GTK host needs on Linux.
    func linuxChecks() -> [Check] {
        let path = SearchPath()
        let environment = ProcessInfo.processInfo.environment
        let module = { (name: String, library: String, minimum: String, package: String) in
            Check(
                component: "\(library) \(minimum) or newer, with its headers", neededBy: "GTK", hosts: [.gtk],
                advice: "Install \(package) (Ubuntu 24.04 or newer has it).") {
                    let version = await ToolOutput.text(.name("pkg-config"), ["--modversion", name])
                    return Self.served(version?.trimmingCharacters(in: .whitespacesAndNewlines), minimum)
                }
        }
        return [
            Check(component: "pkg-config", neededBy: "GTK", hosts: [.gtk], advice: "Install pkg-config.") {
                Self.present(path.find("pkg-config")?.path)
            },
            module("gtk4", "GTK", "4.14", "libgtk-4-dev"),
            module("libadwaita-1", "libadwaita", "1.5", "libadwaita-1-dev"),
            Check(
                component: "WebKitGTK 6.0, with its headers",
                neededBy: "GTK's web view (lib/Backends/WebView.GTK), the GTK host's tests included", hosts: [],
                advice: "Install libwebkitgtk-6.0-dev on Ubuntu, webkitgtk-6.0 on Arch: the web view's backend links it.") {
                    let version = await ToolOutput.text(.name("pkg-config"), ["--modversion", "webkitgtk-6.0"])
                    return Self.served(version?.trimmingCharacters(in: .whitespacesAndNewlines), "2.40")
                },
            Check(
                component: "gdk-pixbuf's SVG loader", neededBy: "GTK's pictures", hosts: [],
                advice: "Install librsvg2-common - or, where gdk-pixbuf reads through glycin, glycin's loaders (glycin on"
                    + " Arch): without one GTK draws no SVG picture.") {
                    var cache = environment["GDK_PIXBUF_MODULE_FILE"].flatMap { $0.isEmpty ? nil : $0 }
                    if cache == nil {
                        cache = await ToolOutput.text(
                            .name("pkg-config"), ["--variable=gdk_pixbuf_cache_file", "gdk-pixbuf-2.0"])?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    let text = cache.flatMap { try? String(contentsOfFile: $0, encoding: .utf8) }
                    return Self.present(text.flatMap { ToolText.svgLoader(inCache: $0) } ?? Self.glycinSVGLoader(environment))
                },
            Check(
                component: "a desktop session", neededBy: "GTK, its test suite included", hosts: [.gtk],
                advice: "Run from a Wayland or X11 session: nothing shows a window without one.") {
                    if let wayland = environment["WAYLAND_DISPLAY"], !wayland.isEmpty { return .found("Wayland (\(wayland))") }
                    if let x11 = environment["DISPLAY"], !x11.isEmpty { return .found("X11 (\(x11))") }
                    return .missing
                },
        ]
    }

    /// glycin's SVG loader among the loader configs of the data folders, where gdk-pixbuf 2.44 and newer read
    /// pictures through glycin.
    static func glycinSVGLoader(_ environment: [String: String]) -> String? {
        let files = FileManager.default
        let home = environment["XDG_DATA_HOME"].flatMap { $0.isEmpty ? nil : $0 }
            ?? files.homeDirectoryForCurrentUser.appendingPathComponent(".local/share").path
        let folders = (environment["XDG_DATA_DIRS"].flatMap { $0.isEmpty ? nil : $0 } ?? "/usr/local/share:/usr/share")
            .split(separator: ":").map(String.init) + [home]
        for folder in folders where !folder.isEmpty {
            let loaders = URL(fileURLWithPath: folder).appendingPathComponent("glycin-loaders")
            for version in ((try? files.contentsOfDirectory(atPath: loaders.path)) ?? []).sorted() {
                let configs = loaders.appendingPathComponent(version).appendingPathComponent("conf.d")
                for file in ((try? files.contentsOfDirectory(atPath: configs.path)) ?? []).sorted() where file.hasSuffix(".conf") {
                    let text = try? String(contentsOf: configs.appendingPathComponent(file), encoding: .utf8)
                    if let loader = text.flatMap({ ToolText.svgLoader(inGlycinConfig: $0) }) { return "glycin's \(loader)" }
                }
            }
        }
        return nil
    }
}
