// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// The pages a window presents over its page, in order, the top one in front - each in a holder on the theme's
/// window background, rising from the bottom as it comes and going down as it leaves.
/// Design: docs/design/platforms/android/pages.md#a-modal-stack
@MainActor
final class AndroidModals {
    /// A presented page, held by its mounted element, which owns its Android half - whole still when the
    /// program has taken it off the stack; and the holder it stands in.
    private struct Shown {
        let element: MountedElement
        let holder: JavaObject
    }

    private var shown: [Shown] = []
    private let root: JavaObject
    private let reducesMotion: () -> Bool

    init(root: JavaObject, reducesMotion: @escaping () -> Bool) {
        self.root = root
        self.reducesMotion = reducesMotion
    }

    /// The page in front, where one is presented.
    var top: AndroidElement? { shown.last?.element.android }

    /// How many pages are presented.
    var count: Int { shown.count }

    /// Presents the modal stack's pages: the ones shown and still described stay, the rest leave from the top,
    /// and each new one rises over the one before; the page in front is the one that shows.
    func present(_ target: [MountedElement], over page: AndroidElement?) {
        var common = 0
        while common < shown.count, common < target.count, shown[common].element === target[common] {
            common += 1
        }
        while shown.count > common { dismissTop(over: page) }

        for element in target[common...] {
            guard let view = element.android.view else { continue }
            (top ?? page)?.setPagePresented(false, reason: .navigation)
            view.forgetPlace()
            let holder = Java.frame {
                Java.callStaticObject(
                    JavaAPI.views, JavaAPI.sheet, .object(AndroidRenderer.context), .object(view.reference)
                ).map(JavaObject.init)
            }
            guard let holder else { continue }
            Java.callStatic(
                JavaAPI.views, JavaAPI.rise, .object(root.reference), .object(holder.reference), .bool(true),
                .long(duration))
            shown.append(Shown(element: element, holder: holder))
            element.android.setPagePresented(true, reason: .navigation)
        }
    }

    /// Takes the page in front down, and the one under it shows again.
    func dismissTop(over page: AndroidElement?) {
        guard let leaving = shown.popLast() else { return }

        leaving.element.android.setPagePresented(false, reason: .navigation)
        Java.callStatic(
            JavaAPI.views, JavaAPI.rise, .object(root.reference), .object(leaving.holder.reference), .bool(false),
            .long(duration))
        (top ?? page)?.setPagePresented(true, reason: .navigation)
    }

    /// How long a page takes to rise or go, in milliseconds: none where the user asks for less motion.
    private var duration: Int64 {
        reducesMotion() ? 0 : 250
    }
}
