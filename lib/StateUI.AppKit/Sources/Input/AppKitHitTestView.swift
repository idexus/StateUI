// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A StateUI-owned AppKit surface: StateUI's input transparency, and a press
/// assistive technology reaches as a click does.
/// Design: docs/design/platforms/appkit/input.md#hit-testing
@MainActor
class AppKitHitTestView: NSView {
    private var ignoresInput = false
    private var transparencyReachesChildren = true

    /// What an accessibility press performs, while the element answers a tap.
    var pressAction: (() -> Void)?

    override func accessibilityPerformPress() -> Bool {
        guard let pressAction else { return false }
        pressAction()
        return true
    }

    /// An element that answers a tap takes the first click into an inactive window.
    /// Design: docs/design/platforms/appkit/input.md#the-first-click
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        pressAction != nil || super.acceptsFirstMouse(for: event)
    }

    func applyInputTransparency(_ transparent: Bool, cascades: Bool) {
        ignoresInput = transparent
        transparencyReachesChildren = cascades
    }

    var inputTransparencyForTesting: (transparent: Bool, cascades: Bool) {
        (ignoresInput, transparencyReachesChildren)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard ignoresInput else { return hitPassingIgnored(point) }
        guard !transparencyReachesChildren else { return nil }

        let target = hitPassingIgnored(point)
        return target === self ? nil : target
    }

    /// What a press at `point` reaches, passing over a native control of the host's that ignores input to what
    /// stands behind it.
    /// Design: docs/design/platforms/appkit/input.md#hit-testing
    private func hitPassingIgnored(_ point: NSPoint) -> NSView? {
        let target = super.hitTest(point)
        guard let target, let ignored = AppKitIgnoredInput.child(of: self, holding: target) else { return target }

        let local = convert(point, from: superview)
        for subview in subviews.reversed()
        where subview !== ignored && !subview.isHidden && !AppKitIgnoredInput.views.contains(subview) {
            if let hit = subview.hitTest(local) { return hit }
        }
        return self
    }
}

/// The native controls of the host - no view of StateUI's own - that ignore input: AppKit has no such flag on a
/// view, so the layout holding one passes over it.
@MainActor
enum AppKitIgnoredInput {
    /// The controls ignoring input now.
    static let views = NSHashTable<NSView>.weakObjects()

    /// Makes `view` ignore input, or take it again.
    static func set(_ view: NSView, ignores: Bool) {
        if ignores { views.add(view) } else { views.remove(view) }
    }

    /// The child of `layout` that holds `target` - itself or an ancestor of it - where that child ignores input.
    static func child(of layout: NSView, holding target: NSView) -> NSView? {
        var current: NSView? = target
        while let view = current, view !== layout {
            if view.superview === layout { return views.contains(view) ? view : nil }
            current = view.superview
        }
        return nil
    }
}

#endif
