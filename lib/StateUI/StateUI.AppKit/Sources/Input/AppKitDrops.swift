// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The drags a window takes - words dragged between views, files dragged from the system. AppKit's dragging
/// destination is the window's root, which finds the view under a drag that takes what it carries - AppKit's own hit
/// test, then that view's ancestors - and tells its element the drag came, went or was let go there.
/// Design: docs/design/platforms/appkit/input.md#a-drag-between-views
@MainActor
final class AppKitDrops {
    /// What a drag carries: words, and the files of the system it holds.
    struct Carried {
        var words: String?
        var files: [URL] = []
    }

    /// The elements whose views take drops, by their view: read as a drag comes.
    private let takers: () -> [ObjectIdentifier: AppKitElement]
    private var targets: [ObjectIdentifier: AppKitElement] = [:]
    private weak var over: AppKitElement?

    init(takers: @escaping () -> [ObjectIdentifier: AppKitElement]) {
        self.takers = takers
    }

    /// A drag came over the window at `location`, in the window, carrying `carried`.
    func entered(at location: NSPoint, carrying carried: Carried, in root: NSView) -> NSDragOperation {
        targets = takers()
        return moved(to: location, carrying: carried, in: root)
    }

    /// The drag moved: the view under it that takes what it carries hears it over it, and the one it left hears it
    /// go.
    func moved(to location: NSPoint, carrying carried: Carried, in root: NSView) -> NSDragOperation {
        let target = taker(at: location, of: carried, in: root)
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

    /// The drag was let go, carrying `carried`: whether a view took it - files where it takes them, else words.
    func dropped(_ carried: Carried) -> Bool {
        guard let target = over else { return false }
        over = nil
        if !carried.files.isEmpty, target.element.dragAndDrop.takesFiles {
            target.hear(.filesDropped(carried.files.map(ChosenFile.init)))
        } else if let words = carried.words {
            target.hear(.dropped(words))
        } else {
            return false
        }
        return true
    }

    /// The element of the view under `location`, in the window, that takes what `carried` holds.
    private func taker(at location: NSPoint, of carried: Carried, in root: NSView) -> AppKitElement? {
        var view = root.hitTest(root.superview?.convert(location, from: nil) ?? location)
        while let each = view, each !== root.superview {
            if let element = targets[ObjectIdentifier(each)] {
                let taking = element.element.dragAndDrop
                if (!carried.files.isEmpty && taking.takesFiles) || (carried.words != nil && taking.takesWords) {
                    return element
                }
            }
            view = each.superview
        }
        return nil
    }
}

extension NSDraggingInfo {
    /// What the drag carries: its words, and the files it holds.
    @MainActor var carried: AppKitDrops.Carried {
        let pasteboard = draggingPasteboard
        let files = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        return AppKitDrops.Carried(words: pasteboard.string(forType: .string), files: files ?? [])
    }
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
