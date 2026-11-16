// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A new application asked for: `project/create`'s parameters.
public struct ApplicationRequest: Codable, Equatable, Sendable {
    /// Its name: letters and digits, starting with a letter.
    public var name: String
    /// What names it to every platform, written in its `stateui.json`; `com.example.<name>` when left out.
    public var identifier: String?
    /// The hosts it has a head for; every host HelloWorld has one for when left out.
    public var platforms: [HostFamily]?
    /// The folder it is made in, as a file URI.
    public var parentUri: String
    /// The StateUI checkout it builds with, as a file URI; the one holding `parentUri`, or beside it, when left out.
    public var checkoutUri: String?

    /// Application `name` in `parentUri`, named `identifier`, with heads for `platforms`, building with `checkoutUri`.
    public init(
        name: String, identifier: String? = nil, platforms: [HostFamily]? = nil, parentUri: String, checkoutUri: String? = nil
    ) {
        self.name = name
        self.identifier = identifier
        self.platforms = platforms
        self.parentUri = parentUri
        self.checkoutUri = checkoutUri
    }
}
