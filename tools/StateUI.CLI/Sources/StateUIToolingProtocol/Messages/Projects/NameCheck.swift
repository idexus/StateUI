// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A name asked about before something is made with it: `name/check`'s parameters.
public struct NameCheck: Codable, Equatable, Sendable {
    /// What it names.
    public var kind: NameKind
    /// The name.
    public var name: String
    /// The folder it would be made in, as a file URI; with none, the name's rule alone is asked.
    public var parentUri: String?

    /// Whether `name` can name a `kind` made in `parentUri`.
    public init(kind: NameKind, name: String, parentUri: String? = nil) {
        self.kind = kind
        self.name = name
        self.parentUri = parentUri
    }
}
