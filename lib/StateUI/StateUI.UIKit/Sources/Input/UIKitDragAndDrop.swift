// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
import UniformTypeIdentifiers
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One view's drags, as UIKit's own interactions: a drag interaction - turned on, as an iPhone leaves it off - carrying
/// the view's words as a string, and a drop interaction taking a drag of words, or of files from the system, copied
/// where the application keeps them. Each tells the host layer what it heard (`HeardInput`), which tells the element
/// by its rules.
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
        let takes = offered.takesWords || offered.takesFiles
        if takes, drop == nil {
            let interaction = UIDropInteraction(delegate: self)
            view.addInteraction(interaction)
            drop = interaction
        } else if !takes, let interaction = drop {
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
        (offered.takesWords && session.canLoadObjects(ofClass: NSString.self))
            || (offered.takesFiles && carriesFiles(session))
    }

    /// Whether the drag carries files - items that are no plain words, or a view taking no words.
    private func carriesFiles(_ session: any UIDropSession) -> Bool {
        guard offered.takesWords else { return session.hasItemsConforming(toTypeIdentifiers: [UTType.item.identifier]) }
        return session.items.contains { !$0.itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: any UIDropSession) -> UIDropProposal {
        heard(.dragOver)
        return UIDropProposal(operation: .copy)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: any UIDropSession) {
        heard(.dragLeft)
    }

    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: any UIDropSession) {
        if offered.takesFiles, carriesFiles(session) {
            let providers = session.items.map(\.itemProvider)
            Task { @MainActor [weak self] in
                var files: [ChosenFile] = []
                for provider in providers {
                    if let file = await Self.kept(provider) { files.append(file) }
                }
                self?.heard(.filesDropped(files))
            }
            return
        }
        _ = session.loadObjects(ofClass: NSString.self) { [weak self] loaded in
            let words = loaded.first.map { String(describing: $0) } ?? ""
            MainActor.assumeIsolated { self?.heard(.dropped(words)) }
        }
    }

    /// The file `provider` holds, copied to a folder of the application's own - UIKit's copy lasts only while it
    /// hands it over - under the name the user knows it by; nil where it holds none.
    private static func kept(_ provider: NSItemProvider) async -> ChosenFile? {
        let type = provider.registeredTypeIdentifiers.first ?? UTType.data.identifier
        let suggested = provider.suggestedName
        return await withCheckedContinuation { done in
            _ = provider.loadFileRepresentation(forTypeIdentifier: type) { url, _ in
                guard let url else { return done.resume(returning: nil) }
                var name = suggested ?? url.lastPathComponent
                if (name as NSString).pathExtension.isEmpty, !url.pathExtension.isEmpty { name += "." + url.pathExtension }
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let file = folder.appendingPathComponent(name)
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: url, to: file)
                    done.resume(returning: ChosenFile(address: file.path, name: name))
                } catch {
                    done.resume(returning: nil)
                }
            }
        }
    }
}
#endif
