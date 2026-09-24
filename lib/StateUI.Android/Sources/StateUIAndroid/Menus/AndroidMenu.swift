// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// A menu's entries - a bar's actions, a view's context menu - written into Android's own menu in one call,
/// `StateUIMenus.fill`; an item chosen comes back by its place among the items.
/// Design: docs/design/platforms/android/menus.md
enum AndroidMenu {
    /// One entry: an item, a submenu and its entries, or a line between groups.
    indirect enum Entry: Equatable {
        case item(Item)
        case menu(String, isEnabled: Bool, [Entry])
        case separator
    }

    /// An item: its words and picture, whether it can be chosen, whether it cannot be undone, and whether it
    /// stands on the bar beside the title rather than in a menu.
    struct Item: Equatable {
        var text: String
        var picture: String?
        var isEnabled = true
        var isDestructive = false
        var onBar = false
    }

    /// Writes `entries` into `menu`, an item chosen reported to `view` by its place among the items.
    @MainActor
    static func fill(_ menu: jobject, view: AndroidView, _ entries: [Entry]) {
        encoded(entries) { kinds, texts, pictures in
            Java.callStatic(
                JavaAPI.menus, JavaAPI.fillMenu, .object(AndroidRenderer.context), .object(menu),
                .long(view.number), .object(kinds), .object(texts), .object(pictures))
        }
    }

    /// Hands `write` the entries as `StateUIMenus` reads them - each one's kind and flags, and each item's
    /// and submenu's words and picture, the pictures none where no entry has one - for one call.
    @MainActor
    static func encoded(_ entries: [Entry], _ write: (_ kinds: jobject?, _ texts: jobject?, _ pictures: jobject?) -> Void) {
        var kinds: [Int32] = []
        var texts: [String] = []
        var pictures: [String?] = []
        encode(entries, kinds: &kinds, texts: &texts, pictures: &pictures)

        Java.frame {
            let bitmaps = pictures.map { $0.flatMap(AndroidPictures.bitmap(named:)) }
            let words = Java.array(of: JavaAPI.string, texts.map { Java.string($0) })
            let images = bitmaps.contains { $0 != nil } ? Java.array(of: JavaAPI.bitmap, bitmaps.map { $0?.reference }) : nil
            withExtendedLifetime(bitmaps) { write(Java.ints(kinds), words, images) }
        }
    }

    /// Each entry as `StateUIMenus` reads it: an int of its kind and flags, and a text and picture for each
    /// item and submenu.
    private static func encode(
        _ entries: [Entry], kinds: inout [Int32], texts: inout [String], pictures: inout [String?]
    ) {
        for entry in entries {
            switch entry {
            case .item(let item):
                kinds.append(
                    (item.isEnabled ? 0 : disabled) | (item.isDestructive ? destructive : 0) | (item.onBar ? onBar : 0))
                texts.append(item.text)
                pictures.append(item.picture)
            case .menu(let text, let isEnabled, let inner):
                kinds.append(menu | (isEnabled ? 0 : disabled))
                texts.append(text)
                pictures.append(nil)
                encode(inner, kinds: &kinds, texts: &texts, pictures: &pictures)
                kinds.append(end)
            case .separator:
                kinds.append(separator)
            }
        }
    }

    private static let menu: Int32 = 1, end: Int32 = 2, separator: Int32 = 3
    private static let disabled: Int32 = 4, destructive: Int32 = 8, onBar: Int32 = 16
}
