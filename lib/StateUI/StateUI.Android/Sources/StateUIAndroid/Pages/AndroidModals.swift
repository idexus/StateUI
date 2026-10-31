// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// The pages a window presents over its page, in order, the top one in front - each in a holder on the theme's
/// window background, rising from the bottom as it comes and going down as it leaves. The pages hear it from the
/// host layer (`WindowPresentation`).
/// Design: docs/design/platforms/android/pages.md#sheets
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


    /// Presents the window's sheets by the host layer's rule (`SheetChange`): the ones shown and still described
    /// stay, the rest leave from the top, and each new one rises over the one before; the page in front is the one
    /// that shows. Whether one rose.
    @discardableResult
    func present(_ target: [MountedElement]) -> Bool {
        let change = SheetChange(from: shown, to: target) { $0.element === $1 }
        for _ in change.leaving { dismissTop() }

        for element in change.coming {
            guard let view = element.android.view else { continue }
            view.forgetPlace()
            let card = Self.card(for: element, in: window)
            let holder = Java.frame {
                Java.callStaticObject(
                    JavaAPI.views, JavaAPI.sheet, .object(AndroidRenderer.context), .object(view.reference),
                    .int(card.width), .int(card.height)
                ).map(JavaObject.init)
            }
            guard let holder else { continue }
            Self.ground(holder, on: element)
            Java.callStatic(
                JavaAPI.views, JavaAPI.rise, .object(root.reference), .object(holder.reference), .bool(true),
                .long(duration))
            shown.append(Shown(element: element, holder: holder))
        }
        return shown.count > change.kept
    }

    /// Stands every sheet on its window's background as it changes (`overlaidGround`).
    func ground() {
        for sheet in shown { Self.ground(sheet.holder, on: sheet.element) }
    }

    /// Stands `holder` on the window's background of `element`'s sheet, laid over the theme's own sheet - Android
    /// blurs nothing behind a view, so a blur stands as its color; the theme's own where the window says none.
    /// Design: docs/design/platforms/android/pages.md#sheets
    private static func ground(_ holder: JavaObject, on element: MountedElement) {
        let argb = element.overlaidGround.painted.flatMap { HostBrush($0).firstColor }.flatMap(AndroidView.argb)
        Java.callStatic(
            JavaAPI.views, JavaAPI.groundSheet, .object(holder.reference),
            .long(argb.map { Int64(UInt32(bitPattern: $0)) } ?? Int64.min))
    }

    /// The color each sheet's holder stands on, by its page, as ARGB; nil where it stands on the theme's own.
    func groundForTesting(of element: MountedElement) -> UInt32? {
        guard let sheet = shown.first(where: { $0.element === element }) else { return nil }
        let argb = Java.callStaticLong(JavaAPI.views, JavaAPI.sheetColor, .object(sheet.holder.reference))
        return argb == Int64.min ? nil : UInt32(truncatingIfNeeded: argb)
    }

    /// Hands what stands over the window to each sheet filling it; a card stands clear of it in the middle.
    func standUnder(_ insets: Clearance) {
        for sheet in shown {
            let fills = Self.card(for: sheet.element, in: window).width == 0
            (sheet.element.android.view as? AndroidLayoutView)?.roomInsets = fills ? insets : .none
        }
    }

    /// Stands each sheet's card in a wide window as large as its page asks now.
    func standAtTheirSizes() {
        for sheet in shown {
            let card = Self.card(for: sheet.element, in: window)
            Java.callStatic(JavaAPI.views, JavaAPI.sizeSheet, .object(sheet.holder.reference), .int(card.width), .int(card.height))
        }
    }

    /// The window's size in points.
    private var window: LayoutSize {
        let context = AndroidRenderer.context
        return LayoutSize(
            width: Double(Java.callStaticInt(JavaAPI.views, JavaAPI.windowDp, .object(context), .bool(true))),
            height: Double(Java.callStaticInt(JavaAPI.views, JavaAPI.windowDp, .object(context), .bool(false))))
    }

    /// The card a sheet stands on in a `window` wide from 600 points on, in pixels (`SheetSize`): at least 280 x 180
    /// points, 560 x 640 for a page asking none, at most a dialog's 560 wide and the window less 24 a side; none in
    /// a narrower one, where the sheet fills the window.
    /// Design: docs/design/platforms/android/pages.md#sheets
    static func card(for element: MountedElement, in window: LayoutSize) -> (width: Int32, height: Int32) {
        guard window.width >= 600 else { return (0, 0) }
        let room = SheetRoom(
            least: LayoutSize(width: 280, height: 180), standard: LayoutSize(width: 560, height: 640),
            most: LayoutSize(width: min(560, window.width - 48), height: window.height - 48))
        let size = SheetSize.size(of: element, in: room) { element.android.layoutItem?.size(offered: $0) ?? room.least }
        let density = AndroidRenderer.density
        return (Int32((size.width * density).rounded()), Int32((size.height * density).rounded()))
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
