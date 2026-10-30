// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One view of a motion layout in the holder its run places, carried while its view is built the same.
/// Design: docs/design/views/motion-layout.md#a-view-in-its-holder
struct LayoutItemView<Content: View>: View, WalkedView {
    let content: Content

    var body: some View {
        Grid { content }
            .letsInputThrough(true)
    }

    var walkedParts: [(label: String, value: Any)] { [("content", content)] }
}
