// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One view of a layout engine in the holder its run places, carried while its view is built the same.
/// Design: docs/design/views/layout-engine.md#a-view-in-its-holder
struct LayoutItemView<Content: View>: View {
    let content: Content

    var body: some View {
        Grid { content }
            .letsInputThrough(true)
    }
}
