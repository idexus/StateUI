// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// A file's real path - every link resolved, as SwiftPM resolves a package's - where `resolvingSymlinksInPath` on
/// macOS leaves `/private` off.
/// Design: docs/design/tooling/projects.md#a-new-application
enum RealPath {
    /// The real path of `url`, which exists; `url` itself where it does not.
    static func of(_ url: URL) -> URL {
        #if os(Windows)
        return url.resolvingSymlinksInPath()
        #else
        guard let resolved = realpath(url.path, nil) else { return url.standardizedFileURL }
        defer { free(resolved) }
        return URL(fileURLWithPath: String(cString: resolved))
        #endif
    }
}
