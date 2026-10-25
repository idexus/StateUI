// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A sheet: a page a view presents, on a card over a veil across the window, under the head of the bar a stack in
/// it brings - its way back, the page's actions around its title, and its close button last.
/// Design: docs/design/platforms/winui/pages.md#sheets
@MainActor
final class WinUISheetView: WinUIView {
    /// What the head's way back and close button do; nil where the head shows none.
    private var back: (() -> Void)?
    private var close: (() -> Void)?

    /// The page's actions on the head.
    private var actions = WinUIBarActions(bar: .sheet)

    init() {
        super.init { number in stateui_winui_sheet_make(number) }
    }

    /// The room a card stands in, a dialog's (`SheetSize`): at least 320 x 184, 548 x 640 for a page asking none;
    /// at most the window less the card's 48 a side, which WinUI's layout holds it to.
    static let room = SheetRoom(
        least: LayoutSize(width: 320, height: 184), standard: LayoutSize(width: 548, height: 640),
        most: LayoutSize(width: 548, height: .infinity))

    /// Shows `page` under `title`, the way back where `back` is one, the page's actions at the head's edges and
    /// behind "more" (`leading`, `trailing`, `overflow`), and the close button where `close` is, each saying `words`;
    /// as large as the page where it `fits`, at the standard size otherwise.
    func show(
        title: String, page: WinUIView?, back: (() -> Void)?, leading: [[WinUIToolbarAction]] = [],
        trailing: [[WinUIToolbarAction]] = [], overflow: [WinUIToolbarAction] = [], close: (() -> Void)?,
        words: ChromeWords, fits: Bool
    ) {
        self.back = back
        self.close = close
        let room = [Self.room.least.width, Self.room.least.height, Self.room.standard.width, Self.room.standard.height]
        stateui_winui_sheet_set(
            handle, title, page?.handle, back != nil, close != nil, words.back, words.close, fits, room)
        menuActions = actions.show(leading: leading, trailing: trailing, overflow: overflow, on: handle)
    }

    /// The ground the card stands on now.
    private var ground = WinUIGround(HostMaterial(nil))

    /// Stands the card on `ground` - its window's background: a color over the card's own, a blur as the in-app
    /// acrylic in its place; the card's own where it is empty.
    /// Design: docs/design/platforms/winui/pages.md#sheets
    func stand(on ground: HostMaterial) {
        let wanted = WinUIGround(ground)
        guard wanted != self.ground else { return }
        self.ground = wanted
        stateui_winui_sheet_set_ground(handle, wanted.kind, wanted.argb, wanted.opacity, wanted.tintOpacity)
    }

    /// The actions on the head as they were last drawn, in reading order, those behind "more" last.
    var drawn: [WinUIToolbarAction] { actions.drawn }

    /// The user pressed the way back (-1), the close button (-2), or an action by its place.
    override func chose(_ index: Int) {
        switch index {
        case -1: back?()
        case -2: close?()
        default: if drawn.indices.contains(index), drawn[index].isEnabled { drawn[index].perform() }
        }
    }
}
