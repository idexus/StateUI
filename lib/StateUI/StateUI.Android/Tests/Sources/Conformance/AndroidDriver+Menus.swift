// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import CStateUIAndroid
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
@_spi(Host) import StateUIConformance

/// Android's own menus as the driver meets them: a stack's bar - its actions, and the page's menus behind its
/// overflow - and a view's context menu, opened as the user opens it. An entry is read and chosen by its item's
/// id, never by its words.
/// Design: docs/design/platforms/android/conformance.md#menus
extension AndroidDriver {
    /// The menus `element` offers: a window's, those on the bar of the stack showing its visible page; a view's,
    /// its context menu.
    func menu(of element: MountedElement) throws -> String {
        if element.type == .window {
            guard let bar = Self.visibleBar(of: element) else { return "" }
            return Self.said(Self.menu(of: bar), menusOnly: true)
        }
        guard let view = (element.native as? AndroidElement)?.view,
              element.children.contains(where: { $0.type == .contextMenu })
        else { throw DriverCannot("read the menu of \(element.type.name)") }
        let menu = TestMenus.empty()
        view.menuOpening(menu.reference)
        return Self.said(menu, menusOnly: false)
    }

    /// A menu's entry or a bar's action chosen as a touch chooses it: nothing where it cannot be chosen.
    func choose(_ element: MountedElement) throws {
        let (menu, id) = try nativeItem(element)
        _ = Java.callStaticBool(Self.testMenus, Self.chooseById, .object(menu.reference), .int(id))
    }

    /// What a menu's entry or a bar's action holds, as Android's item holds it.
    func itemHolds(_ property: Prop, _ element: MountedElement) throws -> HostValue? {
        let (menu, id) = try nativeItem(element)
        let held = Java.frame {
            Java.callStaticObject(
                Self.testMenus, Self.heldById, .object(TestContext.context.reference), .object(menu.reference), .int(id)
            ).map { Java.text($0) }
        }
        guard let lines = held?.split(separator: "\n", omittingEmptySubsequences: false), lines.count == 4 else {
            throw DriverCannot(reading: property, of: element)
        }
        switch property {
        case .text: return String(lines[0]).propValue
        case .isEnabled: return (lines[1] == "1").propValue
        case .isDestructive: return (lines[2] == "1").propValue
        case .icon: throw DriverCannot("read a picture's name", because: "Android's item keeps its picture, not its name")
        default: throw DriverCannot(reading: property, of: element)
        }
    }

    /// The native menu `element` stands in and its item's id: the context menu of the view holding it, opened
    /// afresh, else the bar whose items it is among.
    private func nativeItem(_ element: MountedElement) throws -> (menu: JavaObject, id: Int32) {
        var each = element.parent
        while let slot = each, slot.type != .contextMenu { each = slot.parent }
        if let holder = each?.parent, let view = (holder.native as? AndroidElement)?.view {
            let menu = TestMenus.empty()
            view.menuOpening(menu.reference)
            guard let place = (element.native as? AndroidElement)?.menuPlace else {
                throw DriverCannot("find \(element.type.name) in its menu")
            }
            return (menu, Int32(place + 1))
        }
        var root = element
        while let parent = root.parent { root = parent }
        for bar in Self.bars(in: root) where bar.items.contains(where: { $0 === element }) {
            guard let place = (element.native as? AndroidElement)?.menuPlace else { break }
            return (Self.menu(of: bar), Int32(place + 1))
        }
        throw DriverCannot("find \(element.type.name) on a bar or in a menu")
    }

    /// The bar of the stack showing the window's visible page; nil where no stack shows it.
    private static func visibleBar(of window: MountedElement) -> AndroidBarView? {
        var each = window.children.first { NodeType.pageTypes.contains($0.type) }?.visiblePage
        while let element = each, element.type != .navigationStack { each = element.parent }
        return ((each?.native as? AndroidElement)?.view as? AndroidNavigationView)?.bar
    }

    /// The bars of every stack under `root`.
    private static func bars(in root: MountedElement) -> [AndroidBarView] {
        let own = ((root.native as? AndroidElement)?.view as? AndroidNavigationView).map { [$0.bar] } ?? []
        return own + (root.children + root.slots).flatMap(bars(in:))
    }

    /// The menu `bar` holds its items in.
    private static func menu(of bar: AndroidBarView) -> JavaObject {
        JavaObject(Java.callObject(bar.reference, TestMenus.getMenu)!)
    }

    /// `menu` as the conformance suite writes a menu (`TestMenus.said`).
    private static func said(_ menu: JavaObject, menusOnly: Bool) -> String {
        Java.frame {
            Java.callStaticObject(testMenus, saidMenu, .object(menu.reference), .bool(menusOnly)).map { Java.text($0) }
        } ?? ""
    }

    private static let testMenus = Java.findClass("stateui/android/test/TestMenus")
    private static let saidMenu = Java.staticMethod(testMenus, "said", "(Landroid/view/Menu;Z)Ljava/lang/String;")
    private static let chooseById = Java.staticMethod(testMenus, "choose", "(Landroid/view/Menu;I)Z")
    private static let heldById = Java.staticMethod(
        testMenus, "held", "(Landroid/content/Context;Landroid/view/Menu;I)Ljava/lang/String;")
}
