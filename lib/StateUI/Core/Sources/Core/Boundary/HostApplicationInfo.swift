// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Manifest facts supplied before a native host asks for its first render.
@_spi(Host) public struct HostApplicationInfo: Equatable, Sendable {
    /// The application name shown to the user.
    public let name: String

    /// The bundle or package identifier.
    public let packageName: String

    /// The user-visible release version.
    public let version: String

    /// The build identifier behind the release version.
    public let build: String

    /// A complete application report.
    public init(
        name: String,
        packageName: String,
        version: String,
        build: String
    ) {
        self.name = name
        self.packageName = packageName
        self.version = version
        self.build = build
    }
}

extension HostApplicationInfo {
    /// What an application's `stateui.json` says, as the tool lays it beside a head whose platform keeps no record of
    /// the application: its name shown, identifier, version and build; nil where `bytes` are no such file.
    /// Design: docs/design/tooling/projects.md#a-head-carries-what-the-application-is
    public init?(applicationFile bytes: [UInt8]) {
        var parser = ValueText.Parser(bytes: bytes)
        guard case .object(let fields)? = parser.document() else { return nil }
        let words = { (key: String) -> String? in
            guard case .string(let value)? = fields.first(where: { $0.key == key })?.value else { return nil }
            return value
        }
        guard let identifier = words("identifier"), let name = words("name"), let version = words("version"),
              case .number(let build)? = fields.first(where: { $0.key == "build" })?.value
        else { return nil }
        self.init(name: name, packageName: identifier, version: version, build: build)
    }
}
