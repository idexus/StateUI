// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page: its content in the room the safe area gives it - clear of what stands over the page, or under it where
/// the content says so - its scroller keeping clear what it reaches under (`SafeAreaArithmetic`).
/// Design: docs/design/platforms/android/pages.md#the-safe-area
@MainActor
final class AndroidPageView: AndroidSingleChildView {
    private weak var page: MountedElement?

    init(page: MountedElement) {
        self.page = page
        super.init()
    }

    override func arrange(in bounds: Rect) {
        guard let item = items.first, item.isShown else { return }

        let safe = Rect(
            x: bounds.x + roomInsets.left, y: bounds.y + roomInsets.top,
            width: max(0, bounds.width - roomInsets.left - roomInsets.right),
            height: max(0, bounds.height - roomInsets.top - roomInsets.bottom))
        let room = SafeAreaArithmetic.room(
            safe: safe, whole: bounds, edges: page?.contentIgnoresSafeArea ?? .none, direction: page?.layoutDirection ?? direction)
        item.view.layout(SingleChildArithmetic.place(of: item, in: room, direction: direction))
        (page?.pageScroller?.android.view as? AndroidScrollView)?.keepClear(
            SafeAreaArithmetic.clearance(room: room, safe: safe))
    }
}
