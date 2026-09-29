// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A tabbed view's row of tabs: the host's `StateUITabs`, a tap on a tab handed on by its place.
@MainActor
final class AndroidTabsView: AndroidView {
    /// What the row does when the user taps a tab.
    var onChosen: ((Int) -> Void)?

    init() {
        super.init { number in
            Java.new(JavaAPI.tabs, JavaAPI.newTabs, .object(AndroidRenderer.context), .long(number))
        }
    }

    /// Shows `row`'s tabs, `chosen` in its own colour.
    func show(_ row: AndroidTabbedView.Row, chosen: Int) {
        Java.frame {
            let titles = Java.array(of: JavaAPI.string, row.tabs.map { Java.string($0.title) })
            let bitmaps = row.tabs.map { $0.picture.flatMap(AndroidPictures.bitmap(named:)) }
            let pictures = Java.array(of: JavaAPI.bitmap, bitmaps.map { $0?.reference })
            withExtendedLifetime(bitmaps) {
                Java.call(
                    reference, JavaAPI.setTabs, .object(titles), .object(pictures), .int(Int32(chosen)),
                    .int(row.background.flatMap(Self.argb) ?? 0), .int(row.color.flatMap(Self.argb) ?? 0),
                    .int(row.chosenColor.flatMap(Self.argb) ?? 0))
            }
        }
    }

    override func detach() {
        super.detach()
        onChosen = nil
    }
}
