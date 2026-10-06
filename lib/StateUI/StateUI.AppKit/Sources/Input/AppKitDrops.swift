// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The drags between views a window takes. AppKit's dragging destination is the window's root, which finds the view
/// under a drag that takes drops - AppKit's own hit test, then that view's ancestors - and tells its element the drag
/// came, went or was let go there with the words it carries.
/// Design: docs/design/platforms/appkit/input.md#a-drag-between-views
@MainActor
final class AppKitDrops {
    /// The elements whose views take drops, by their view: read as a drag comes.
    private let takers: () -> [ObjectIdentifier: AppKitElement]
    private var targets: [ObjectIdentifier: AppKitElement] = [:]
    private weak var over: AppKitElement?

    init(takers: @escaping () -> [ObjectIdentifier: AppKitElement]) {
        self.takers = takers
    }

    /// A drag came over the window at `location`, in the window, carrying `words` - nil for none.
    func entered(at location: NSPoint, carrying words: String?, in root: NSView) -> NSDragOperation {
        targets = takers()
        return moved(to: location, carrying: words, in: root)
    }

    /// The drag moved: the view under it that takes drops - none for a drag carrying no words - hears it over it, and
    /// the one it left hears it go.
    func moved(to location: NSPoint, carrying words: String?, in root: NSView) -> NSDragOperation {
        let target = words == nil ? nil : taker(at: location, in: root)
        if target !== over {
            over?.hear(.dragLeft)
            over = target
        }
        target?.hear(.dragOver)
        return target == nil ? [] : .copy
    }

    func exited() {
        over?.hear(.dragLeft)
        over = nil
    }

    /// The drag was let go, carrying `words`: whether a view took them.
    func dropped(_ words: String?) -> Bool {
        guard let target = over, let words else { return false }
        over = nil
        target.hear(.dropped(words))
        return true
    }

    /// The element of the view under `location`, in the window, that takes drops.
    private func taker(at location: NSPoint, in root: NSView) -> AppKitElement? {
        var view = root.hitTest(root.superview?.convert(location, from: nil) ?? location)
        while let each = view, each !== root.superview {
            if let element = targets[ObjectIdentifier(each)] { return element }
            view = each.superview
        }
        return nil
    }
}

extension NSDraggingInfo {
    /// The words the drag carries; nil for none.
    @MainActor var words: String? { draggingPasteboard.string(forType: .string) }
}

extension AppKitRenderer {
    /// The elements whose views take drops, by their view.
    func dropTakers() -> [ObjectIdentifier: AppKitElement] {
        var takers: [ObjectIdentifier: AppKitElement] = [:]
        for element in runtime.tree.root?.takingDrops ?? [] {
            if let view = element.appKit.view { takers[ObjectIdentifier(view)] = element.appKit }
        }
        return takers
    }
}
#endif
