// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One tab as a row shows it: the title of the page it presents, and that page's picture.
/// Design: docs/design/platforms/winui/pages.md#tabs
struct WinUITab: Equatable {
    let title: String
    /// Its picture as the relay reads it (`WinUIPictures.lines`); none for its title alone.
    let icon: [String]

    /// The tab of the page `page` - a page, or an arrangement a tabbed view presents.
    @MainActor init(of page: MountedElement) {
        title = page.value(.title)?.string ?? ""
        icon = WinUIPictures.lines(HostPicture(page.value(.icon)))
    }
}
