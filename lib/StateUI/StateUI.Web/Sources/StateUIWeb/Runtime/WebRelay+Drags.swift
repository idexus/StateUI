// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWeb

/// A drag between views, in Swift's words: what an element offers and takes, and what its drag listener heard.
/// Design: docs/design/platforms/web/input.md#a-drag-between-views
extension WebRelay {
    /// The element `element`'s drag carries `offered`'s words, and it takes drops as `offered` says; `listener`
    /// hears it.
    static func offerDrag(_ element: Int32, _ offered: DragAndDrop, _ listener: Int32) {
        utf8(offered.words ?? "") {
            stateui_web_offer_drag(
                element, $0, $1, offered.words == nil ? 0 : 1, offered.takesDrops ? 1 : 0, listener)
        }
    }

    /// What the drag listener being heard heard.
    static var dragHeard: HeardInput? {
        switch Int(stateui_web_event_number(0)) {
        case 0: .dragStarted
        case 1: .dragEnded
        case 2: .dragOver
        case 3: .dragLeft
        case 4: .dropped(copyRead(length: stateui_web_drag_words()))
        default: nil
        }
    }
}
