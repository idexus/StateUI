// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The name one layer of a window's overlays stands under.
///
///     extension OverlayKey {
///         static let offline = OverlayKey("offline")
///     }
///
///     window.overlays[.offline] = OfflineBanner()
///
/// A key is the layer's identity: writing another view under it replaces the
/// view in its place, and the other layers keep theirs as it comes and goes.
public struct OverlayKey: Hashable, Sendable, CustomStringConvertible {
    /// The name, the application's own.
    public let name: String

    /// A key from its name.
    ///
    ///     static let offline = OverlayKey("offline")
    ///
    /// - Parameter name: what the layer is called - unique among a window's.
    public init(_ name: String) {
        self.name = name
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }
}

extension OverlayKey {
    /// The layer a docked inspector stands in, over every other.
    static let inspector = OverlayKey("stateui.inspector")
}
