// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ToolbarItemsContract` on a host: the items the visible page writes stand on its bar, those of a page pushed over
/// it in their place, and the first page's again on the way back.
@_spi(Host) public enum ToolbarItemsTests: ConformanceFamily {
    public static let name = "ToolbarItems"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("theVisiblePagesItemsStandOnItsBar", covers: [
                Covered(ToolbarItemsContract.self), Covered(MenuItemElementContract.clicked, on: "ToolbarItem"),
            ]) { s in
                let path = State(wrappedValue: [Int]())
                let heard = Received<String>()
                s.start {
                    NavigationStack(path.projectedValue) {
                        SessionPage { page, _ in
                            page.toolbarItems = [ToolbarItem("Save").onClicked { heard.values.append("save") }.id("save")]
                        }
                    } destination: { _ in
                        SessionPage { page, _ in
                            page.toolbarItems = [ToolbarItem("Share").onClicked { heard.values.append("share") }.id("share")]
                        }
                    }
                }

                try s.perform(.activate, on: s.element("save"))
                s.settle { heard.values == ["save"] }

                path.wrappedValue = [1]
                s.settle { (try? s.element("share")) != nil }
                try s.perform(.activate, on: s.element("share"))
                s.settle { heard.values.count == 2 }
                s.expect(heard.values, ["save", "share"], "each page's own, while it is the visible one")
            },
        ]
    }
}
