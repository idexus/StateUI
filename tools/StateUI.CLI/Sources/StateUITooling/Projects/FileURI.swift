// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A path as the API writes one: an absolute, percent-encoded file URI.
public enum FileURI {
    /// The URI of `url`'s file, a folder's with no slash after its name.
    public static func string(_ url: URL) -> String {
        let uri = RealPath.lexical(url).absoluteString
        return uri.hasSuffix("/") && url.pathComponents.count > 1 ? String(uri.dropLast()) : uri
    }

    /// The path `uri` names as the machine whose file it is writes it: `C:\\Users\\…` for a Windows drive's - a guest's
    /// file told on a Mac - else the path itself.
    public static func shown(_ uri: String) -> String {
        if uri.hasPrefix("file:///"), let rest = String(uri.dropFirst(8)).removingPercentEncoding,
           let drive = rest.first, drive.isLetter, rest.dropFirst().first == ":" {
            return rest.replacingOccurrences(of: "/", with: "\\")
        }
        return (try? url(uri).path) ?? uri
    }

    /// The file `uri` names.
    ///
    /// - Throws: ``ToolingError`` when `uri` is no file URI.
    public static func url(_ uri: String) throws(ToolingError) -> URL {
        guard let url = URL(string: uri), url.isFileURL else {
            throw ToolingError(.projectNotFound, "\(uri) is no file URI.")
        }
        return RealPath.lexical(url)
    }
}
