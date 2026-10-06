// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A kind of file a dialog offers: what the user reads it as, and the
/// extensions its files end in.
///
///     let page = FileType("HTML page", extensions: ["html", "htm"])
///     let file = try await Dialogs.openFile(types: [page])
///
/// The dialog that opens files shows only these; the one that saves offers
/// them to choose from, the first chosen.
///
/// Design: docs/design/core/acts.md#files
public struct FileType: Equatable, Hashable, Sendable, HostRepresentable {
    /// What the user reads the kind as, in their own language.
    public let caption: String

    /// The extensions its files end in, without the dot, in lowercase.
    public let extensions: [String]

    /// A kind of file read as `caption`, its files ending in `extensions` -
    /// `"html"`, `".html"` and `"*.html"` alike, each once.
    public init(_ caption: String, extensions: [String]) {
        self.caption = caption
        var kept: [String] = []
        for written in extensions {
            let bare = String(written.drop { $0 == "*" || $0 == "." }).lowercased()
            if !bare.isEmpty, !kept.contains(bare) { kept.append(bare) }
        }
        self.extensions = kept
    }

    /// The caption, then the extensions.
    public var propValue: PropValue { .values([.string(caption), .strings(extensions)]) }

    /// The kind back from its caption and its extensions, or nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let parts = propValue.values, parts.count == 2,
              let caption = parts[0].string, let extensions = parts[1].strings
        else { return nil }

        self.init(caption, extensions: extensions)
    }
}
