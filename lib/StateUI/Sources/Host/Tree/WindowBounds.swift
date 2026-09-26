// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The least and greatest size a window's element allows, in DIPs, the same on every host: nil where it says
/// nothing, which leaves the toolkit's own, and a greatest never below the least.
/// Design: docs/design/host/tree.md#a-windows-frame
@_spi(Host) public struct WindowBounds: Equatable, Sendable {
    /// The least width, where said.
    public var minimumWidth: Double?

    /// The least height, where said.
    public var minimumHeight: Double?

    /// The greatest width, where said.
    public var maximumWidth: Double?

    /// The greatest height, where said.
    public var maximumHeight: Double?

    /// What `window` allows now: each a finite size not negative, a greatest smaller than the least being the least.
    @MainActor public init(of window: MountedElement) {
        minimumWidth = WindowFrame.extent(.minimumWidth, of: window)
        minimumHeight = WindowFrame.extent(.minimumHeight, of: window)
        maximumWidth = WindowFrame.extent(.maximumWidth, of: window).map { [minimumWidth] in max($0, minimumWidth ?? 0) }
        maximumHeight = WindowFrame.extent(.maximumHeight, of: window)
            .map { [minimumHeight] in max($0, minimumHeight ?? 0) }
    }
}
