// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A new application asked for: `project/create`'s parameters.
public struct ApplicationRequest: Codable, Equatable, Sendable {
    /// Its name: letters and digits, starting with a letter.
    public var name: String
    /// The folder it is made in, as a file URI.
    public var parentUri: String
    /// The StateUI checkout it builds with, as a file URI; the one holding `parentUri`, or beside it, when left out.
    public var checkoutUri: String?

    /// Application `name` in `parentUri`, building with `checkoutUri`.
    public init(name: String, parentUri: String, checkoutUri: String? = nil) {
        self.name = name
        self.parentUri = parentUri
        self.checkoutUri = checkoutUri
    }
}
