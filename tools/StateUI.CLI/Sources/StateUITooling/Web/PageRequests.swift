// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// What the page's server answers a request with, decided apart from the network: the file a path names within the
/// page's folder - never outside it, by `..` or by a link - and its type.
/// Design: docs/design/tooling/web-heads.md#the-pages-server
enum PageRequests {
    /// The file `target` names within `root` - its query aside, percent-decoded, a folder's `index.html` - or `nil`
    /// where it names none there, or leaves the folder.
    static func file(for target: String, in root: URL) -> URL? {
        let path = String(target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
        guard let decoded = path.removingPercentEncoding, !decoded.contains("\0") else { return nil }
        let parts = decoded.split(separator: "/").map(String.init)
        guard !parts.contains("..") else { return nil }
        let base = root.resolvingSymlinksInPath().standardizedFileURL
        var file = parts.reduce(base) { $0.appendingPathComponent($1) }
        var folder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: file.path, isDirectory: &folder) else { return nil }
        if folder.boolValue { file = file.appendingPathComponent("index.html") }
        let resolved = file.resolvingSymlinksInPath().standardizedFileURL
        guard resolved.path.hasPrefix(base.path + "/"), FileManager.default.fileExists(atPath: resolved.path) else { return nil }
        return resolved
    }

    /// The type a file is served as, by its extension.
    static func type(of file: URL) -> String {
        [
            "html": "text/html; charset=utf-8", "js": "text/javascript; charset=utf-8", "mjs": "text/javascript; charset=utf-8",
            "css": "text/css; charset=utf-8", "wasm": "application/wasm", "svg": "image/svg+xml", "png": "image/png",
            "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif", "webp": "image/webp", "ico": "image/x-icon",
            "json": "application/json", "txt": "text/plain; charset=utf-8",
        ][file.pathExtension.lowercased()] ?? "application/octet-stream"
    }
}
