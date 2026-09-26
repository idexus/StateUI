// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitWindowController {
    func synchronizeModals(_ target: [AppKitElement]) {
        guard let window else { return }

        var common = 0
        while common < modals.count, common < target.count,
              modals[common].node === target[common] {
            modals[common].synchronize(target[common])
            common += 1
        }

        while modals.count > common {
            let index = modals.count - 1
            let parent = index == 0 ? window : (modals[index - 1].window ?? window)
            modals.removeLast().dismiss(from: parent)
        }

        for index in common..<target.count {
            let modal = AppKitModalWindowController(node: target[index], owner: self)
            let parent = modals.last?.window ?? window
            modals.append(modal)
            modal.present(over: parent, actuallyPresent: presentsWindow)
        }
    }

    func userDismissed(_ modal: AppKitModalWindowController) {
        guard let window, modals.last === modal else { return }
        let previous = modal.node.element
        let parent = modals.count == 1
            ? window
            : (modals[modals.count - 2].window ?? window)
        modals.removeLast().dismiss(from: parent)
        let next = modals.last?.node ?? presentedPage

        previous.appKit.setPagePresented(false, reason: .navigation)
        next?.setPagePresented(true, reason: .navigation)
        refreshVisiblePageChrome()
        host?.commit(node?.handler(.modalPopped), payload: [.number(Double(modals.count))])
    }

    func dismissTopModalForTesting() {
        guard let modal = modals.last else { return }
        userDismissed(modal)
    }
}

#endif
