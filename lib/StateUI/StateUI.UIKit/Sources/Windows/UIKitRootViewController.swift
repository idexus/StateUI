// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a scene's window shows: the controller of the window's arrangement of pages, over the whole window - each
/// page stands within the safe area its bars leave - the overlays laid over it, and the pages presented over it as
/// sheets, each over the one before.
/// Design: docs/design/platforms/uikit/pages.md#sheets
@MainActor
final class UIKitRootViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    private var shown: UIViewController?
    private var overlays: [UIView] = []

    /// The sheets shown, the first presented by this controller, each next by the one before.
    private var sheets: [UIViewController] = []

    /// What the window does when the user took the top sheet away, handed how many stay.
    var onSheetDismissed: ((Int) -> Void)?

    /// The shortcuts the window's tree states - those giving way to typing left out while a field is typed into
    /// - and what a pressed one does: UIKit holds a key command on a responder, not on a control, so the window's
    /// root offers every one of them.
    var shortcuts: (_ typing: Bool) -> [KeyboardShortcut] = { _ in [] }
    var onShortcut: ((KeyboardShortcut) -> Void)?

    /// The keys the views holding the keyboard take (`KeyPresses`), and what a pressed one does: offered before the
    /// window's shortcuts, alone and with Shift.
    var keys: () -> [Key] = { [] }
    var onKey: ((KeyboardShortcut) -> Void)?

    override var keyCommands: [UIKeyCommand]? {
        let taken = keys().flatMap { key in [KeyModifiers(), .shift].map { KeyboardShortcut(key, modifiers: $0) } }
        return taken.map { UIKitKeys.command($0, action: #selector(pressedKey(_:))) }
            + shortcuts(UIKitFirstResponder.isTyping).filter { !taken.contains($0) }
                .map { UIKitKeys.command($0, action: #selector(pressedShortcut(_:))) }
    }

    @objc func pressedKey(_ command: UIKeyCommand) {
        UIKitKeys.shortcut(of: command).map { onKey?($0) }
    }

    @objc func pressedShortcut(_ command: UIKeyCommand) {
        UIKitKeys.shortcut(of: command).map { onShortcut?($0) }
    }

    /// What a menu's entry stating a shortcut does, chosen from its menu or pressed on the menu bar: the entry the
    /// command is known by chosen.
    var onMenuEntry: ((UInt64) -> Void)?

    /// What UIKit setting out to give the window a new size - the screen turned, the scene resized - tells, before
    /// it lays the window out at that size.
    var onResizing: (() -> Void)?

    @objc func chooseMenuEntry(_ command: UIKeyCommand) {
        (command.propertyList as? NSNumber).map { onMenuEntry?($0.uint64Value) }
    }

    /// The sheets last asked for before the window stood on screen, or while a sheet moved: UIKit presents over a
    /// controller only once it stands, and over none whose sheet is still coming or going.
    /// Design: docs/design/platforms/uikit/pages.md#sheets
    private var waiting: (sheets: [UIViewController], animated: Bool)?
    private var appeared = false

    /// Whether a presentation or a dismissal this controller asked for has not ended.
    private var moving = false

    /// What passes over the sheets - a question, a file dialog, a preview - asked for and not yet shown, and the one
    /// presented or on its way, with whether it has its answer: the root presents everything over its window, one
    /// thing at a time. Design: docs/design/platforms/uikit/pages.md#what-passes-over-the-sheets
    private var passing: [UIViewController] = []
    private var standing: (controller: UIViewController, answered: Bool)?

    /// Counts the windows the root stood in: a movement's end counts only in the one it began in. And whether it
    /// comes back into one with what UIKit kept presented over it.
    private var generation = 0
    private var returning = false

    override func loadView() {
        view = UIView()
        view.backgroundColor = .systemBackground
    }

    /// Shows `arrangement` in place of the one before.
    func show(_ arrangement: UIViewController?) {
        guard arrangement !== shown else { return }
        if let shown {
            shown.willMove(toParent: nil)
            shown.view.removeFromSuperview()
            shown.removeFromParent()
        }
        shown = arrangement
        guard let arrangement else { return }
        addChild(arrangement)
        arrangement.view.frame = view.bounds
        arrangement.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(arrangement.view, at: 0)
        arrangement.didMove(toParent: self)
    }

    /// Lays `overlays` over the arrangement, the first lowest, within the safe area, in place of those before.
    func lay(_ overlays: [UIView]) {
        guard !overlays.elementsEqual(self.overlays, by: ===) else { return }
        for leaving in self.overlays where !overlays.contains(where: { $0 === leaving }) { leaving.removeFromSuperview() }
        self.overlays = overlays
        for overlay in overlays { view.addSubview(overlay) }
        view.setNeedsLayout()
    }

    /// Presents `sheets` over the arrangement by the host layer's rule (`SheetChange`): those shown and still asked
    /// for stay, the rest go from the top, and each new one comes over the one before once that one stands - UIKit
    /// presents over a controller only then.
    func present(_ sheets: [UIViewController], animated: Bool) {
        guard appeared, !moving, standing == nil else { return waiting = (sheets, animated) }
        let change = SheetChange(from: self.sheets, to: sheets) { $0 === $1 }
        let (common, coming) = (change.kept, change.coming)
        guard common < self.sheets.count else { return presentEach(coming, animated: animated) }
        let presenter = common == 0 ? self : self.sheets[common - 1]
        self.sheets = Array(self.sheets.prefix(common))
        guard presenter.presentedViewController != nil else { return presentEach(coming, animated: animated) }
        moving = true
        presenter.dismiss(animated: animated && coming.isEmpty, completion: ending { root in
            root.moved { root.presentEach(coming, animated: animated) }
        })
    }

    private func presentEach(_ coming: [UIViewController], animated: Bool) {
        guard let sheet = coming.first else { return presentPassing() }
        let presenter = sheets.last ?? self
        sheet.modalPresentationStyle = .pageSheet
        sheet.presentationController?.delegate = self
        sheets.append(sheet)
        moving = true
        presenter.present(sheet, animated: animated && coming.count == 1, completion: ending { root in
            root.moved { root.presentEach(Array(coming.dropFirst()), animated: animated) }
        })
    }

    /// What a movement does once it ended - nothing where the window it began in has gone.
    private func ending(_ next: @escaping (UIKitRootViewController) -> Void) -> () -> Void {
        let generation = generation
        return { [weak self] in
            guard let self, self.generation == generation else { return }
            next(self)
        }
    }

    /// A presentation or a dismissal ended: the sheets asked for meanwhile come next, else `next`.
    private func moved(else next: () -> Void) {
        moving = false
        guard let (sheets, animated) = waiting else { return next() }
        waiting = nil
        present(sheets, animated: animated)
    }

    /// Presents `controller` - a question, a file dialog, a preview - over the top sheet once nothing moves and what
    /// passed before has gone; sheets asked for while it stands come once it has gone (`passed`).
    func pass(_ controller: UIViewController) {
        passing.append(controller)
        if !moving { presentPassing() }
    }

    /// `controller` has its answer: it goes, or went, and what waits comes once it has gone.
    func passed(_ controller: UIViewController) {
        passing.removeAll { $0 === controller }
        guard standing?.controller === controller else { return }
        standing?.answered = true
        if !moving { letPassingGo() }
    }

    /// The first thing passing, over the top sheet - centered where it stands as a popover with no anchor of its own.
    private func presentPassing() {
        guard appeared, !moving, standing == nil, waiting == nil, !passing.isEmpty else { return }
        let next = passing.removeFirst()
        let presenter = sheets.last ?? self
        if let popover = next.popoverPresentationController, popover.sourceView == nil, popover.barButtonItem == nil {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        standing = (next, false)
        moving = true
        presenter.present(next, animated: true, completion: ending { root in
            root.moving = false
            if root.standing?.answered == true { root.letPassingGo() }
        })
    }

    /// The answered thing passing goes - UIKit's own dismissal let finish, else one asked here - and then what waits.
    private func letPassingGo() {
        guard let controller = standing?.controller else { return }
        let gone = ending { root in
            root.standing = nil
            root.moved { root.presentPassing() }
        }
        moving = true
        if controller.presentingViewController == nil {
            gone()
        } else if controller.isBeingDismissed, let coordinator = controller.transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { _ in gone() }
        } else {
            controller.presentingViewController?.dismiss(animated: true) { gone() }
        }
    }

    /// The window left its scene: no movement under way ends there. What is asked for - the sheets, then what
    /// passes - comes again once the window stands in the next scene, over nothing (`clearWhatStands`).
    func windowLeft() {
        generation += 1
        let asked = waiting?.sheets ?? sheets
        if let standing, !standing.answered { passing.insert(standing.controller, at: 0) }
        standing = nil
        sheets = []
        moving = false
        appeared = false
        returning = true
        waiting = (asked, false)
    }

    /// Takes away what UIKit kept presented over the root as it came back with the window - UIKit takes it away
    /// itself, in its own time, and drops what is presented over it meanwhile.
    private func clearWhatStands() {
        guard presentedViewController != nil else { return }
        moving = true
        dismiss(animated: false, completion: ending { root in root.moved {} })
    }

    /// Tells nobody of its sheets any more: they leave with the window.
    func letGo() {
        onSheetDismissed = nil
        sheets = []
        waiting = nil
    }

    /// The user took the top sheet away - swiped it down: the window hears how many stay.
    func presentationControllerDidDismiss(_ presentation: UIPresentationController) {
        guard let index = sheets.firstIndex(where: { $0 === presentation.presentedViewController }) else { return }
        sheets.removeSubrange(index...)
        onSheetDismissed?(index)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appeared = true
        if returning {
            returning = false
            clearWhatStands()
            if moving { return }
        }
        if let (sheets, animated) = waiting {
            waiting = nil
            present(sheets, animated: animated)
        } else {
            presentPassing()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        onResizing?()
        super.viewWillTransition(to: size, with: coordinator)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        for overlay in overlays { overlay.frame = view.bounds.inset(by: view.safeAreaInsets) }
    }
}
#endif
