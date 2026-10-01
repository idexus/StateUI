// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A layout of the tree's standing in the window's toolbar. AppKit measures a toolbar item's view by its constraints
/// and warns of any it measures at nothing, so the slot holds the layout at the size StateUI measures it at, and a
/// layout holding nothing stands out of the toolbar - the slot tells the toolbar as that changes.
/// Design: docs/design/platforms/appkit/runtime.md#the-toolbar
@MainActor
final class AppKitToolbarSlot: NSView {
    /// The layout the slot holds.
    let held: NSView

    /// What the slot does when its layout comes to hold something, or nothing.
    var onEmptied: (() -> Void)?

    /// Whether the layout holds nothing, so the slot stands out of the toolbar.
    private(set) var holdsNothing = true

    /// The size the slot holds it at.
    private lazy var width = widthAnchor.constraint(equalToConstant: 0)
    private lazy var height = heightAnchor.constraint(equalToConstant: 0)

    init(holding held: NSView) {
        self.held = held
        super.init(frame: .zero)
        addSubview(held)
        NSLayoutConstraint.activate([width, height])
        measure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitToolbarSlot is made in code")
    }

    /// A measurement forgotten below climbs to here, out of the toolbar too, and asks for a layout: the slot takes
    /// its size again.
    override var needsLayout: Bool {
        didSet { if needsLayout { measure() } }
    }

    override func layout() {
        super.layout()
        held.frame = bounds
    }

    private func measure() {
        let size = (held as? AppKitWidthConstrainedMeasuring)?.fittingContentSize(width: nil) ?? held.fittingSize
        (width.constant, height.constant) = (size.width, size.height)
        let nothing = size.width <= 0 || size.height <= 0
        guard nothing != holdsNothing else { return }
        holdsNothing = nothing
        onEmptied?()
    }
}
#endif
