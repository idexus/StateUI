// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// The outline of a figure made of a blur or glass, drawn over it: the figure's own drawing lies under the surface it
/// is made of, which would hide its line.
/// Design: docs/design/platforms/appkit/views.md#a-figure-made-of-a-material
@MainActor
final class AppKitShapeOutline: NSView {
    private weak var figure: AppKitShapeView?

    init(_ figure: AppKitShapeView) {
        self.figure = figure
        super.init(frame: figure.bounds)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitShapeOutline is made in code")
    }

    override var isFlipped: Bool { true }

    /// The whole of the view under a transform, which AppKit leaves out of what it takes for visible.
    override var visibleRect: NSRect { drawnRect(visible: super.visibleRect) }

    override func draw(_ dirtyRect: NSRect) {
        figure?.strokeOutline(in: bounds)
    }

    /// Takes no click: the figure under it does.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

#endif
