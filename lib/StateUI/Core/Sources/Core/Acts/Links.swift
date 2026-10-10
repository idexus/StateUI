// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Addresses launched, as an act: the system opens them in their application.
// Design: docs/design/core/acts.md#launching

/// Addresses the system opens in the application it gives them, asked of the
/// host.
public enum Links {
    /// Opens an address in the application the system gives it - a web page in
    /// the browser, a mail address in the mail application.
    ///
    ///     try await Links.launch("https://www.swift.org")
    ///
    /// - Parameter address: the address, its scheme included.
    /// - Returns: whether an application took it; false where none opens its
    ///   scheme.
    @discardableResult
    public static func launch(_ address: String) async throws -> Bool {
        try await stateUICall(ApplicationContract.launchLink, address)
    }
}
