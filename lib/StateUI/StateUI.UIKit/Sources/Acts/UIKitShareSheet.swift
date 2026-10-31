// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIApple

/// The words and the link offered in UIKit's activity sheet, presented over what the window shows - from its
/// middle on an iPad - and answered once: whether the user completed an activity with them.
/// Design: docs/design/platforms/uikit/runtime.md#sharing
@MainActor
final class UIKitShareSheet {
    /// What is offered, as the host layer reads it.
    let shared: HostShare

    /// The sheet, once it is presented.
    private(set) var controller: UIActivityViewController?

    private var answer: ((Result<Bool, ActFailure>) -> Void)?

    init(_ shared: HostShare) {
        self.shared = shared
    }

    /// Presents the sheet through the window's `root`; `answer` hears once whether the user shared.
    func offer(in root: UIKitRootViewController, answer: @escaping (Result<Bool, ActFailure>) -> Void) {
        self.answer = answer
        let controller = UIActivityViewController(activityItems: shared.items, applicationActivities: nil)
        controller.completionWithItemsHandler = { [weak self] _, completed, _, _ in
            MainActor.assumeIsolated { self?.finish(completed) }
        }
        if let popover = controller.popoverPresentationController {
            let view = root.view!
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        self.controller = controller
        root.pass(controller)
    }

    /// A test's answer for the user: shared, or cancelled - the sheet taken away.
    func answerForTesting(shared: Bool) {
        controller?.dismiss(animated: false)
        finish(shared)
    }

    /// Tells whether the user shared, once.
    private func finish(_ shared: Bool) {
        answer?(.success(shared))
        answer = nil
    }
}
#endif
