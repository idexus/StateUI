// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The browsers a page opens in.
/// Design: docs/design/tooling/destinations.md#browsers
enum Browsers {
    /// Opens `url` in browser `id`: `default` the system's own.
    static func open(_ url: String, in id: String) async {
        #if os(macOS)
        await ToolStep.regardless(.name("open"), id == "default" ? [url] : ["-b", id, url])
        #else
        await ToolStep.regardless(.name("xdg-open"), [url])
        #endif
    }
}
