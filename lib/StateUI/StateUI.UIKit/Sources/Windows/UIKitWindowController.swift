// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One StateUI window in a window scene of its own: its arrangement of pages in the scene's window, within the safe
/// area, its title the scene's, as the host layer presents a window (`WindowPresentation`).
/// Design: docs/design/platforms/uikit/runtime.md#scenes
@MainActor
final class UIKitWindowController {
    /// The scene's window; nil for a StateUI window no scene stands for yet.
    private(set) var window: UIWindow?

    /// What the window shows behind its pages, as its element last said; nil for UIKit's own.
    private var background: UIColor?

    /// The session of the scene the window stands in, which the user closes the window by.
    private(set) var session: UISceneSession?

    /// The phase the window was last told; nil until it was told one.
    var toldPhase: ApplicationPhase?

    /// The record its session keeps, for iOS to hand back as it restores the scene.
    private(set) var record: WindowRecord?

    /// What the window does as the user comes to it or goes to another: iPadOS keeps every window on screen active
    /// and dims those the user is not in, which their scene's active appearance tells.
    var onFrontMoved: ((UIWindowScene) -> Void)?

    /// What the window's scene tells as UIKit sets out to give the window a new size, standing turned already: the
    /// display is told then, before the window is laid out at that size.
    /// Design: docs/design/platforms/uikit/runtime.md#the-environment
    var onResizing: ((UIWindowScene) -> Void)?

    /// The scene's active appearance followed, while the window stands in it.
    private var frontWatch: (scene: UIWindowScene, registration: UITraitChangeRegistration)?

    private let root = UIKitRootViewController()
    let presentation = WindowPresentation()

    init(_ element: MountedElement, scene: UIWindowScene?) {
        if let scene { stand(in: scene) }
    }

    /// Whether the window stands for the scene session `session`.
    func holds(_ session: UISceneSession) -> Bool {
        self.session?.persistentIdentifier == session.persistentIdentifier
    }

    /// Writes the record `make` makes of the window, given its session's identity, in the session - where it
    /// changed.
    func keep(_ make: (String) -> WindowRecord) {
        guard let session else { return }
        let record = make(session.persistentIdentifier)
        guard record != self.record else { return }
        self.record = record
        session.userInfo = (session.userInfo ?? [:]).merging([UIKitRenderer.recordKey: record.text]) { $1 }
    }

    /// iOS let the scene go, and its window with it; the session stays, for the scene to come back.
    func sceneLeft() {
        stopWatchingFront()
        root.windowLeft()
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }

    /// Stands the window in `scene`, which iOS connected for it.
    func stand(in scene: UIWindowScene) {
        guard window == nil else { return }
        let window = UIWindow(windowScene: scene)
        window.backgroundColor = background
        window.overrideUserInterfaceStyle = UIKitActToolkit.style(HostThemes.held)
        window.tintColor = UIKitActToolkit.tint(HostAccents.held)
        window.rootViewController = root
        root.onResizing = { [weak self, weak scene] in
            guard let scene else { return }
            self?.onResizing?(scene)
        }
        window.makeKeyAndVisible()
        self.window = window
        session = scene.session
        let registration = scene.registerForTraitChanges([UITraitActiveAppearance.self]) {
            [weak self] (scene: UIWindowScene, _: UITraitCollection) in
            self?.onFrontMoved?(scene)
        }
        frontWatch = (scene, registration)
    }

    /// Stops following the scene's active appearance, as the window leaves it.
    private func stopWatchingFront() {
        guard let frontWatch else { return }
        frontWatch.scene.unregisterForTraitChanges(frontWatch.registration)
        self.frontWatch = nil
    }

    /// Shows what the window holds now: the arrangement of pages it shows, and the title of the page the user
    /// sees.
    func present(_ element: MountedElement, in runtime: HostRuntime) {
        let changes = presentation.show(element, in: runtime.lifecycle)
        root.shortcuts = { [weak element] typing in
            guard let element else { return [] }
            let onMenuBar = KeyboardShortcuts.onMenuBar(under: element)
            return KeyboardShortcuts.stated(under: element, typing: typing).filter { !onMenuBar.contains($0) }
        }
        root.onShortcut = { [weak runtime, weak element] shortcut in
            guard let runtime, let element else { return }
            KeyboardShortcuts.press(shortcut, under: element, in: runtime)
        }
        root.keys = { [weak self, weak element] in
            guard let self, let element else { return [] }
            return KeyPresses.taken(focused: Self.keyboardHolder(under: element), front: presentation.frontPage)
        }
        root.onKey = { [weak self, weak runtime, weak element] pressed in
            guard let self, let runtime, let element else { return }
            KeyPresses.press(
                pressed.key, modifiers: pressed.modifiers, focused: Self.keyboardHolder(under: element),
                front: presentation.frontPage, in: runtime)
        }
        root.onMenuEntry = { [weak runtime, weak element] mount in
            guard let runtime, let entry = element?.first(mount: mount), entry.isEffectivelyEnabled else { return }
            entry.chosen(in: runtime)
        }
        if let traits = changes.traits {
            background = traits.background.painted.flatMap(UIColor.init(stateUI:))
            window?.backgroundColor = background
        }
        if let (_, arrangement) = changes.arrangement {
            root.show(arrangement?.uiKit.controller)
        }
        if let overlays = changes.overlays {
            root.lay(overlays.compactMap(\.uiKit.view))
        }
        if let sheets = changes.sheets {
            // The sheets over the `remaining` that stay go, the top first.
            root.onSheetDismissed = { [weak self, weak runtime, weak element] remaining in
                guard let self, let runtime, let element else { return }
                runtime.goBack(.dismissSheets(presentation.sheets.dropFirst(remaining).reversed()), in: element)
            }
            root.present(sheets.compactMap(\.uiKit.controller), animated: !runtime.reducesMotion())
        }
        presentation.arrangement?.uiKit.composeChrome()
        presentation.sheets.forEach { $0.uiKit.composeChrome() }
        presentation.sheets.forEach(askSize)
        let title = presentation.arrangement?.titledPage?.value(.title)?.string
        window?.windowScene?.title = title.flatMap { $0.isEmpty ? nil : $0 } ?? element.value(.title)?.string
        // Every page shows the window's background where it paints none of its own, the arrangement in place.
        if changes.traits != nil { window?.rootViewController?.showPageBackgrounds() }
    }

    /// Asks UIKit to stand `sheet` as large as its page asks, within a form sheet's room on the window - which a wide
    /// screen keeps and a narrow one passes over - and at UIKit's own size where the page asks none (`SheetSize`).
    /// Design: docs/design/platforms/uikit/pages.md#sheets
    private func askSize(of sheet: MountedElement) {
        guard let controller = sheet.uiKit.controller, let bounds = window?.bounds.size else { return }
        let room = SheetRoom(
            least: Self.leastSheet, standard: LayoutSize(width: 0, height: 0),
            most: LayoutSize(width: Double(bounds.width) - 64, height: Double(bounds.height) - 64))
        let size = SheetSize.asks(sheet)
            ? SheetSize.size(of: sheet, in: room) { sheet.uiKit.layoutItem?.size(offered: $0) ?? room.least }
            : room.standard
        let asked = CGSize(width: size.width, height: size.height)
        if controller.preferredContentSize != asked { controller.preferredContentSize = asked }
    }

    /// The least a sheet stands at on a wide screen.
    private static let leastSheet = LayoutSize(width: 320, height: 180)

    /// The element under `element` holding the keyboard: the deepest whose view holds the first responder.
    private static func keyboardHolder(under element: MountedElement) -> MountedElement? {
        guard let responder = UIKitFirstResponder.find() as? UIView else { return nil }
        return KeyPresses.holder(under: element) { held in
            (held.native as? UIKitElement)?.view.map { responder === $0 || responder.isDescendant(of: $0) } ?? false
        }
    }

    /// The menus of the page the user sees - the top sheet's, else the arrangement's - as the host layer composes
    /// them from its path.
    var pageMenus: [MenuEntry] {
        (presentation.sheets.last ?? presentation.arrangement)?.visiblePage?.chromeMenus.menus ?? []
    }

    /// The tree let the window go: its scene goes with it.
    func close() {
        let session = window?.windowScene?.session
        hide()
        guard let session else { return }
        UIApplication.shared.requestSceneSessionDestruction(session, options: nil)
    }

    /// Takes the window out of its scene, which stays: its sheets go with it, heard by nobody - the tree that asked
    /// for them is gone.
    func hide() {
        stopWatchingFront()
        root.letGo()
        window?.isHidden = true
        window?.windowScene = nil
    }
}
#endif
