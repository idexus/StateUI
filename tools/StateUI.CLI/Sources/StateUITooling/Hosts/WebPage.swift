// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A Web head's page, laid beside its module: `index.html` from the host's template - the application's names, its
/// own scripts and its head's `head.html` written in - the relay `stateui-web.js` and its look `stateui-web.css`, the
/// module `<Name>Web.wasm`, the head's `Page/*.js`, and the application's pictures in `Images`, as they are.
/// Design: docs/design/tooling/web-heads.md#the-page
struct WebPage {
    var application: URL
    var name: String
    /// The module's product: `GalleryWeb`.
    var product: String
    /// The folder SwiftPM laid the module in.
    var binaries: URL
    /// The StateUI checkout: the host's relay, look and page template.
    var library: URL
    /// What a script's and the look's addresses carry, so a browser never shows an older build: the build's second.
    var stamp: Int

    /// Lays the page in `staging`.
    func assemble(in staging: URL) throws {
        let files = FileManager.default
        let relay = library.appendingPathComponent("lib/StateUI/StateUI.Web/JavaScript")
        try files.copyItem(at: binaries.appendingPathComponent("\(product).wasm"), to: staging.appendingPathComponent("\(product).wasm"))
        for file in ["stateui-web.js", "stateui-web.css"] {
            try files.copyItem(at: relay.appendingPathComponent(file), to: staging.appendingPathComponent(file))
        }
        let page = application.appendingPathComponent("Platforms/Web/Page")
        let scripts = ((try? files.contentsOfDirectory(atPath: page.path)) ?? []).filter { $0.hasSuffix(".js") }.sorted()
        for script in scripts {
            try files.copyItem(at: page.appendingPathComponent(script), to: staging.appendingPathComponent(script))
        }
        let head = (try? String(contentsOf: page.appendingPathComponent("head.html"), encoding: .utf8)) ?? ""
        let template = try String(contentsOf: relay.appendingPathComponent("index.html"), encoding: .utf8)
        try Data(Self.index(template, head: head, application: name, module: "\(product).wasm", scripts: scripts, stamp: stamp).utf8)
            .write(to: staging.appendingPathComponent("index.html"))
        let images = application.appendingPathComponent("Resources/Images")
        if files.fileExists(atPath: images.path) {
            try files.copyItem(at: images, to: staging.appendingPathComponent("Images"))
        }
    }

    /// The page's `index.html`: `template`'s marks written - `{{application}}` the name the page says as it loads (the
    /// head's `application-name`, else its `<title>`, else `application`, a quote written as HTML's), `{{module}}`,
    /// `{{stamp}}`, `{{scripts}}` each script loaded before the application starts - and the line `{{head}}` the
    /// head as written, after a `<title>` named after the application where the head names none.
    static func index(_ template: String, head: String, application: String, module: String, scripts: [String], stamp: Int) -> String {
        let named = head.range(of: "<title", options: .caseInsensitive) != nil
        let meta = head.firstMatch(of: /(?i)<meta[^>]*name="application-name"[^>]*>/).flatMap { tag in
            String(tag.output).firstMatch(of: /content="([^"]*)"/).map { String($0.1) }
        }
        let title = head.firstMatch(of: /(?i)<title>([^<]*)<\/title>/).map { String($0.1) }
        let shown = [meta, title, application].compactMap { $0 }.first { !$0.isEmpty } ?? application
        let loaded = scripts.map { "<script type=\"module\" src=\"./\($0)?v=\(stamp)\"></script>" }.joined()
        let written = { (line: Substring) in
            line.replacingOccurrences(of: "{{application}}", with: shown.replacingOccurrences(of: "\"", with: "&quot;"))
                .replacingOccurrences(of: "{{module}}", with: module).replacingOccurrences(of: "{{stamp}}", with: "\(stamp)")
                .replacingOccurrences(of: "{{scripts}}", with: loaded)
        }
        var headLines = head.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if headLines.last == "" { headLines.removeLast() }
        return template.split(separator: "\n", omittingEmptySubsequences: false).flatMap { line -> [String] in
            // The head stands as written: only the template's own marks are filled.
            line == "{{head}}" ? (named ? [] : ["<title>\(application)</title>"]) + headLines : [written(line)]
        }.joined(separator: "\n")
    }
}
