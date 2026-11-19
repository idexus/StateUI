// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The choices asked for: `settings/get`'s parameters.
public struct SettingsRequest: Codable, Equatable, Sendable {
    /// A folder of the project, as a file URI; the connection's workspace when left out.
    public var projectUri: String?
    /// The application whose choices are asked for, by name; the one the project means when left out.
    public var application: String?

    /// The choices of `application` of the project at `projectUri`.
    public init(projectUri: String? = nil, application: String? = nil) {
        self.projectUri = projectUri
        self.application = application
    }
}
