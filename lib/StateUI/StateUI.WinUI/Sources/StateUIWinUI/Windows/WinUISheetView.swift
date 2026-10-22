// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A sheet: a page a view presents, on a card over a veil across the window, under the head of the bar a stack in
/// it brings - its way back, its title and its close button.
/// Design: docs/design/platforms/winui/pages.md#sheets
@MainActor
final class WinUISheetView: WinUIView {
    /// What the head's way back and close button do; nil where the head shows none.
    private var back: (() -> Void)?
    private var close: (() -> Void)?

    init() {
        super.init { number in stateui_winui_sheet_make(number) }
    }

    /// The room a card stands in, a dialog's (`SheetSize`): at least 320 x 184, 548 x 640 for a page asking none;
    /// at most the window less the card's 48 a side, which WinUI's layout holds it to.
    static let room = SheetRoom(
        least: LayoutSize(width: 320, height: 184), standard: LayoutSize(width: 548, height: 640),
        most: LayoutSize(width: 548, height: .infinity))

    /// Shows `page` under `title`, the way back where `back` is one and the close button where `close` is, each
    /// saying `words`; as large as the page where it `fits`, at the standard size otherwise.
    func show(
        title: String, page: WinUIView?, back: (() -> Void)?, close: (() -> Void)?, words: ChromeWords, fits: Bool
    ) {
        self.back = back
        self.close = close
        let room = [Self.room.least.width, Self.room.least.height, Self.room.standard.width, Self.room.standard.height]
        stateui_winui_sheet_set(
            handle, title, page?.handle, back != nil, close != nil, words.back, words.close, fits, room)
    }

    /// The user pressed the way back (-1) or the close button (-2).
    override func chose(_ index: Int) {
        switch index {
        case -1: back?()
        case -2: close?()
        default: break
        }
    }
}
