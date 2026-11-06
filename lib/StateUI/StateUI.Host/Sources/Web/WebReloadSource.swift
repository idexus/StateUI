// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The complete source to use until a native document can reload itself.
@_spi(Host) public struct WebReloadSource {
    /// The current requested source; nil lets the native document reload itself.
    public private(set) var value: WebViewSource?

    /// No document has been requested.
    public init() {}

    /// A request replaces the complete source, including authored HTML and its base.
    public mutating func requested(_ source: WebViewSource) {
        value = source
    }

    /// Native content committed; authored HTML with a base still needs its bytes.
    public mutating func committed() {
        if case .html(_, .some)? = value { return }
        value = nil
    }

    /// A native navigation leaves the authored document for its own history.
    public mutating func takenOver() {
        value = nil
    }
}
