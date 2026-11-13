// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `OpenedLinkElementContract` on a host: a link the application is asked to open, given to the window a page or an
/// arrangement stands in as its page, is heard by it - each case made for every element wearing the tier.
@_spi(Host) public enum OpenedLinkElementTests: ConformanceFamily {
    public static let name = "OpenedLinkElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(OpenedLinkElementContract.self).map(PageElementTests.linked)
    }
}
