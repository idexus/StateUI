// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIApple

/// The words and the link offered in AppKit's sharing picker, shown from the middle of its window's content and
/// answered once: shared where the service the user chose says it shared them, else not.
/// Design: docs/design/platforms/appkit/runtime.md#sharing
@MainActor
final class AppKitShareSheet: NSObject, @MainActor NSSharingServicePickerDelegate, @MainActor NSSharingServiceDelegate {
    /// What is offered, as the host layer reads it.
    let shared: HostShare

    private var answer: ((Result<Bool, ActFailure>) -> Void)?

    init(_ shared: HostShare) {
        self.shared = shared
    }

    /// Shows the picker over `view` where `presents`, else holds it unshown; `answer` hears once whether the user
    /// shared.
    func offer(over view: NSView, presenting presents: Bool, answer: @escaping (Result<Bool, ActFailure>) -> Void) {
        self.answer = answer
        guard presents else { return }
        let picker = NSSharingServicePicker(items: shared.items)
        picker.delegate = self
        let middle = NSRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        picker.show(relativeTo: middle, of: view, preferredEdge: .minY)
    }

    /// A test's answer for the user: shared, or cancelled.
    func answerForTesting(shared: Bool) {
        finish(shared)
    }

    func sharingServicePicker(_ picker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        if service == nil { finish(false) }
    }

    func sharingServicePicker(
        _ picker: NSSharingServicePicker, delegateFor sharingService: NSSharingService
    ) -> (any NSSharingServiceDelegate)? {
        self
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        finish(true)
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: any Error) {
        finish(false)
    }

    /// Tells whether the user shared, once.
    private func finish(_ shared: Bool) {
        answer?(.success(shared))
        answer = nil
    }
}
#endif
