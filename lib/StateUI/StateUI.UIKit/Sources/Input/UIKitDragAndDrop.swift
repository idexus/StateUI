// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One view's drag between views, as UIKit's own interactions: a drag interaction - turned on, as an iPhone leaves it
/// off - carrying the view's words as a string, and a drop interaction taking a drag that carries words. Each tells
/// the host layer what it heard (`HeardInput`), which tells the element by its rules.
/// Design: docs/design/platforms/uikit/input.md#a-drag-between-views
@MainActor
final class UIKitDragAndDrop: NSObject, UIDragInteractionDelegate, UIDropInteractionDelegate {
    private weak var view: UIView?
    private let heard: (HeardInput) -> Void
    private var drag: UIDragInteraction?
    private var drop: UIDropInteraction?

    /// What a drag of the view carries and whether it takes drops, as it stands.
    private(set) var offered = DragAndDrop.none

    init(view: UIView, heard: @escaping (HeardInput) -> Void) {
        self.view = view
        self.heard = heard
    }

    /// Puts on the view the interactions `offered` asks for, and takes away those it no longer does.
    func offer(_ offered: DragAndDrop) {
        guard let view else { return }
        self.offered = offered
        if offered.words != nil, drag == nil {
            let interaction = UIDragInteraction(delegate: self)
            interaction.isEnabled = true
            view.addInteraction(interaction)
            drag = interaction
        } else if offered.words == nil, let interaction = drag {
            view.removeInteraction(interaction)
            drag = nil
        }
        if offered.takesDrops, drop == nil {
            let interaction = UIDropInteraction(delegate: self)
            view.addInteraction(interaction)
            drop = interaction
        } else if !offered.takesDrops, let interaction = drop {
            view.removeInteraction(interaction)
            drop = nil
        }
    }

    func detach() {
        offer(.none)
    }

    /// What the view hears of a drag, told as UIKit's interactions tell it.
    func hearForTesting(_ input: HeardInput) {
        heard(input)
    }

    // MARK: - The drag of the view

    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: any UIDragSession) -> [UIDragItem] {
        guard let words = offered.words else { return [] }
        return [UIDragItem(itemProvider: NSItemProvider(object: words as NSString))]
    }

    func dragInteraction(_ interaction: UIDragInteraction, sessionWillBegin session: any UIDragSession) {
        heard(.dragStarted)
    }

    func dragInteraction(_ interaction: UIDragInteraction, session: any UIDragSession, didEndWith operation: UIDropOperation) {
        heard(.dragEnded)
    }

    // MARK: - A drag over the view

    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: any UIDropSession) -> Bool {
        session.canLoadObjects(ofClass: NSString.self)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: any UIDropSession) -> UIDropProposal {
        heard(.dragOver)
        return UIDropProposal(operation: .copy)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: any UIDropSession) {
        heard(.dragLeft)
    }

    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: any UIDropSession) {
        _ = session.loadObjects(ofClass: NSString.self) { [weak self] loaded in
            let words = loaded.first.map { String(describing: $0) } ?? ""
            MainActor.assumeIsolated { self?.heard(.dropped(words)) }
        }
    }
}
#endif
