// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import CStateUIAndroid
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
@_spi(Host) import StateUIConformance

/// What the Android driver reads of a tabbed view's row of tabs and does to it: a tab tapped, the one marked
/// selected as TalkBack tells it, and a tab's words and picture - each tab by its page's place.
/// Design: docs/design/platforms/android/conformance.md#what-the-driver-reads
extension AndroidDriver {
    /// The pictures the suite shows, which a tab's picture is told by: the one whose pixels it shows.
    static let pictures = ["test_dot.png", "test_wide.png", "photo.png"]

    /// The row of tabs of the tabbed view `tabs`.
    static func row(of tabs: AndroidTabView) -> AndroidTabsView? {
        tabs.heldViews().lazy.compactMap { $0 as? AndroidTabsView }.first
    }

    /// The user taps the tab at `place`.
    static func tap(tab place: Int, of tabs: AndroidTabView) -> Bool {
        guard let row = row(of: tabs) else { return false }
        return Java.callStaticBool(testTabs, tapTab, .object(row.reference), .int(Int32(place)))
    }

    /// The place of the tab the row marks selected; nil for none.
    static func selectedTab(of tabs: AndroidTabView) -> Int? {
        guard let row = row(of: tabs) else { return nil }
        let place = Java.callStaticInt(testTabs, selectedTabPlace, .object(row.reference))
        return place < 0 ? nil : Int(place)
    }

    /// The title or the icon of the tab the page or arrangement `element` stands on, as its tab shows it.
    func tabHolds(_ property: Prop, of element: MountedElement, in tabs: MountedElement) throws -> HostValue? {
        guard let view = (tabs.native as? AndroidElement)?.view as? AndroidTabView, let row = Self.row(of: view),
              let place = tabs.children.firstIndex(where: { $0 === element })
        else { throw DriverCannot(reading: property, of: element) }
        switch property {
        case .title:
            return Java.frame {
                Java.callStaticObject(Self.testTabs, Self.tabTitle, .object(row.reference), .int(Int32(place)))
                    .map { .string(Java.text($0)) }
            }
        case .icon:
            let shown = Self.pictures.first { name in
                guard let picture = AndroidPictures.bitmap(named: name) else { return false }
                return Java.callStaticBool(
                    Self.testTabs, Self.tabShows, .object(row.reference), .int(Int32(place)), .object(picture.reference))
            }
            return shown.map { .string($0) }
        default: throw DriverCannot(reading: property, of: element)
        }
    }

    static let testTabs = Java.findClass("stateui/android/test/TestTabs")
    static let tabTitle = Java.staticMethod(testTabs, "title", "(Landroid/view/ViewGroup;I)Ljava/lang/String;")
    static let tabShows = Java.staticMethod(
        testTabs, "shows", "(Landroid/view/ViewGroup;ILandroid/graphics/Bitmap;)Z")
    static let selectedTabPlace = Java.staticMethod(testTabs, "selected", "(Landroid/view/ViewGroup;)I")
    static let tapTab = Java.staticMethod(testTabs, "tap", "(Landroid/view/ViewGroup;I)Z")
}
