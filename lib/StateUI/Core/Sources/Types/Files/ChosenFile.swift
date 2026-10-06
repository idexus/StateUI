// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A file the user opened or saved in a dialog: its name, and its contents
/// read through the host.
///
///     if let file = try await Dialogs.openFile(types: [page]) {
///         let html = String(decoding: try await file.read(), as: UTF8.self)
///     }
///
/// Where it stands is the platform's own - a path, a document's address, a
/// browser's handle - so the host reads and launches it. It stays good while
/// the application runs.
///
/// Design: docs/design/core/acts.md#files
public struct ChosenFile: Equatable, Hashable, Sendable, HostRepresentable {
    /// The file's name as the platform shows it, its extension included.
    public let name: String

    /// Where the platform keeps the file: a path, a document's address, a handle.
    @_spi(Host) public let address: String

    /// The file at `address`, shown as `name`.
    @_spi(Host) public init(address: String, name: String) {
        self.address = address
        self.name = name
    }

    /// Where it stands, then its name.
    public var propValue: PropValue { .strings([address, name]) }

    /// The file back from where it stands and its name, or nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let parts = propValue.strings, parts.count == 2 else { return nil }

        self.init(address: parts[0], name: parts[1])
    }

    /// Reads the file whole.
    ///
    ///     let bytes = try await file.read()
    ///
    /// - Returns: its contents, as they stand.
    /// - Throws: `StateUIError` where the platform cannot read it - gone,
    ///   or no longer the application's to read.
    public nonisolated(nonsending) func read() async throws -> [UInt8] {
        try await stateUICall(ApplicationContract.readFile, self)
    }

    /// Opens the file in the application the system gives its kind - a page
    /// in the browser, a picture in the viewer.
    ///
    ///     try await report.launch()
    ///
    /// - Returns: whether an application took it; false where none opens its
    ///   kind.
    @discardableResult
    public nonisolated(nonsending) func launch() async throws -> Bool {
        try await stateUICall(ApplicationContract.launchFile, self)
    }
}
