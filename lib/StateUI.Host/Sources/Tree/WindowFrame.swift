// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A window's place and size as its element asks, the same on every host: four requests in DIPs, each alone, the
/// place counted from the corner of the screen's work area.
/// Design: docs/design/host/tree.md#a-windows-frame
@_spi(Host) public struct WindowFrame: Equatable, Sendable {
    /// Where the window's left edge stands, where asked.
    public var x: Double?

    /// Where the window's top edge stands, where asked.
    public var y: Double?

    /// The window's width, where asked.
    public var width: Double?

    /// The window's height, where asked.
    public var height: Double?

    /// A frame asking for what it is given, nothing where given nil.
    public init(x: Double? = nil, y: Double? = nil, width: Double? = nil, height: Double? = nil) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// What `window` asks for now: a place where it says a finite number, a size where it says one not negative.
    @MainActor public init(of window: MountedElement) {
        let place = { (property: Prop) in window.value(property)?.number.flatMap { $0.isFinite ? $0 : nil } }
        self.init(
            x: place(.x), y: place(.y), width: Self.extent(.width, of: window),
            height: Self.extent(.height, of: window))
    }

    /// What of this frame the tree changed since `last`: each request alone, nil where it kept one or asks none -
    /// a request kept leaves the window where the user put it.
    public func changes(since last: WindowFrame) -> WindowFrame {
        WindowFrame(
            x: x != last.x ? x : nil, y: y != last.y ? y : nil,
            width: width != last.width ? width : nil, height: height != last.height ? height : nil)
    }

    /// Whether it asks for nothing.
    public var isEmpty: Bool {
        x == nil && y == nil && width == nil && height == nil
    }

    /// The size `window` says for `property`, where it is a finite number not negative.
    @MainActor static func extent(_ property: Prop, of window: MountedElement) -> Double? {
        window.value(property)?.number.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    }
}
