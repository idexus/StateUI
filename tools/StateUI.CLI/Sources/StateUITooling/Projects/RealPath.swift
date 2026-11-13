// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// A file's real path - every link resolved, as SwiftPM resolves a package's - and a path's dots taken out: where
/// `resolvingSymlinksInPath` and `standardizedFileURL` on macOS leave `/private` off.
/// Design: docs/design/tooling/projects.md#a-new-application
enum RealPath {
    /// The real path of `url`, which exists; `url` itself where it does not.
    static func of(_ url: URL) -> URL {
        #if os(Windows)
        return url.resolvingSymlinksInPath()
        #else
        guard let resolved = realpath(url.path, nil) else { return lexical(url) }
        defer { free(resolved) }
        return URL(fileURLWithPath: String(cString: resolved))
        #endif
    }

    /// `url` with each `.` left out and each `..` taking the folder before it, and nothing else rewritten.
    static func lexical(_ url: URL) -> URL {
        #if os(Windows)
        return url.standardizedFileURL
        #else
        var parts: [Substring] = []
        for part in url.path.split(separator: "/") where part != "." {
            if part == ".." { _ = parts.popLast() } else { parts.append(part) }
        }
        return URL(fileURLWithPath: "/" + parts.joined(separator: "/"), isDirectory: url.hasDirectoryPath)
        #endif
    }
}
