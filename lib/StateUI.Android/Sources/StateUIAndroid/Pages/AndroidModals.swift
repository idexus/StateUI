// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// The pages a window presents over its page, in order, the top one in front - each in a holder on the theme's
/// window background, rising from the bottom as it comes and going down as it leaves. The pages hear it from the
/// host layer (`WindowPresentation`).
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


    /// Presents the modal stack's pages: the ones shown and still described stay, the rest leave from the top,
    /// and each new one rises over the one before; the page in front is the one that shows. Whether one rose.
    @discardableResult
    func present(_ target: [MountedElement]) -> Bool {
        var common = 0
        while common < shown.count, common < target.count, shown[common].element === target[common] {
            common += 1
        }
        while shown.count > common { dismissTop() }

        for element in target[common...] {
            guard let view = element.android.view else { continue }
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
        }
        return shown.count > common
    }

    /// Takes the page in front down, and the one under it shows again.
    private func dismissTop() {
        guard let leaving = shown.popLast() else { return }

        Java.callStatic(
            JavaAPI.views, JavaAPI.rise, .object(root.reference), .object(leaving.holder.reference), .bool(false),
            .long(duration))
    }

    /// How long a page takes to rise or go, in milliseconds: none where the user asks for less motion.
    private var duration: Int64 {
        reducesMotion() ? 0 : 250
    }
}
