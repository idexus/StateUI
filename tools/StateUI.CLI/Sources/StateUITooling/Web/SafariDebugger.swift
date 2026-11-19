// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// Safari's WebAssembly debugger, which LLDB reaches through its `webinspector-wasm` platform - a program Safari 27
/// lays - once Safari's feature flag turns it on: each page a debuggable, named by its WebContent process.
/// Design: docs/design/tooling/runs.md#on-the-web
enum SafariDebugger {
    static let browser = "com.apple.Safari"
    /// The program LLDB's `webinspector-wasm` platform starts.
    static let platform = URL(fileURLWithPath: "/System/Cryptexes/App/usr/libexec/webinspector-wasm-lldb-platform")
    /// The feature flag that offers Safari's pages to the debugger, each opened after it is turned on.
    static let flag = "Develop > Feature Flags > Experimental WebAssembly Debugger (Disables JIT)"

    /// Whether this Mac's Safari has its WebAssembly debugger.
    static var present: Bool { FileManager.default.isExecutableFile(atPath: platform.path) }

    /// Safari's version, of the application the system runs.
    static var version: String? {
        ["/System/Cryptexes/App/System/Applications/Safari.app", "/Applications/Safari.app"].lazy
            .compactMap { Bundle(path: $0)?.infoDictionary?["CFBundleShortVersionString"] as? String }.first
    }

    /// The pages `listing` - LLDB's `platform process list` - names: each page's process, and its name, its host.
    static func pages(in listing: String) -> [Int: String] {
        Dictionary(listing.split(whereSeparator: \.isNewline).compactMap { line -> (Int, String)? in
            let fields = line.split(separator: " ", maxSplits: 2)
            guard fields.count == 3, let page = Int(fields[0]), Int(fields[1]) != nil else { return nil }
            return (page, fields[2].trimmingCharacters(in: .whitespaces))
        }, uniquingKeysWith: { first, _ in first })
    }

    /// The page opening `url` made: one `after` lists and `before` did not, of `url`'s host.
    static func opened(_ url: String, before: [Int: String], after: [Int: String]) -> Int? {
        let host = URL(string: url)?.host
        return after.filter { before[$0.key] == nil && $0.value == host }.keys.min()
    }

    /// `url` carrying `run`, so Safari loads the page anew rather than bringing forward a tab of an earlier run.
    static func address(_ url: String, run: Int) -> String {
        url + (url.contains("?") ? "&" : "?") + "STATEUI_RUN=\(run)"
    }

    #if os(macOS)
    /// The pages Safari's debugger offers now, as `lldb` lists them.
    static func pages(lldb: URL) async -> [Int: String] {
        pages(in: await ToolOutput.text(.path(lldb.path), ["-b", "-o", "platform select webinspector-wasm", "-o", "platform process list"]) ?? "")
    }

    /// Opens `url` in Safari and answers its page's process: the one the debugger offers that it did not before, within
    /// `patience`; none appearing, the flag is off.
    static func open(_ url: String, lldb: URL, patience: Duration = .seconds(30)) async throws -> Int {
        let before = await pages(lldb: lldb)
        await Browsers.open(url, in: browser)
        let clock = ContinuousClock()
        let end = clock.now + patience
        while clock.now < end {
            if let page = opened(url, before: before, after: await pages(lldb: lldb)) { return page }
            try await Task.sleep(for: .milliseconds(500))
        }
        throw ToolingError(.invalidConfiguration, "Safari offers no WebAssembly debugger for the page: turn on \(flag) - Settings, Advanced, Show features for web developers first - and run again.")
    }
    #endif
}
