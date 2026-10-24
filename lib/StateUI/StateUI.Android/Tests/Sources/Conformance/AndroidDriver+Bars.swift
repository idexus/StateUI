// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import CStateUIAndroid
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
@_spi(Host) import StateUIConformance

/// What the Android driver reads of the bar an arrangement declares: Android's toolbar over the page it shows - the
/// line under its title, the color it is painted and the color its title is drawn in.
extension AndroidDriver {
    /// `property` of the bar the page `element` shows stands under; nil where no stack gives that page a bar.
    static func barHolds(_ property: Prop, of element: MountedElement) -> HostValue? {
        // A split view's name and mark stand on its sidebar's own bar.
        if element.type == .splitView, [.barTitle, .barIcon].contains(property),
           let split = (element.native as? AndroidElement)?.view as? AndroidSplitView {
            return sidebarBarHolds(property, split.drawer.bar)
        }
        var each = element.visiblePage
        while let found = each, found.type != .navigationStack { each = found.parent }
        guard let bar = ((each?.native as? AndroidElement)?.view as? AndroidNavigationView)?.bar else { return nil }
        switch property {
        case .barSubtitle:
            return Java.frame {
                Java.callStaticObject(testBars, barSubtitle, .object(bar.reference)).map { .string(Java.text($0)) }
            }
        case .barBackgroundColor, .barForegroundColor:
            let reading = property == .barBackgroundColor ? barBackground : barForeground
            let argb = UInt32(bitPattern: Java.callStaticInt(testBars, reading, .object(bar.reference)))
            guard argb != 0 else { return nil }
            return .color(
                red: UInt8(argb >> 16 & 0xFF), green: UInt8(argb >> 8 & 0xFF), blue: UInt8(argb & 0xFF),
                alpha: UInt8(argb >> 24))
        default:
            return nil
        }
    }

    /// Whether the stack a page stands on shows its bar over it, and offers the way back there - Android's toolbar
    /// as it stands while that page is on top; nil where the page stands on no stack.
    static func pageBarHolds(_ property: Prop, of page: MountedElement) -> HostValue? {
        guard let stack = page.parent, stack.type == .navigationStack,
              let bar = ((stack.native as? AndroidElement)?.view as? AndroidNavigationView)?.bar
        else { return nil }
        switch property {
        case .showsNavigationBar:
            return Java.callStaticBool(testBars, barShown, .object(bar.reference)).propValue
        case .showsTitle:
            return Java.callStaticBool(testBars, barTitled, .object(bar.reference)).propValue
        case .showsBackButton:
            let words = Java.frame {
                Java.callStaticObject(testBars, barNavigation, .object(bar.reference)).map { Java.text($0) }
            }
            return (words == "Back").propValue
        case .showsCloseButton:
            let words = Java.frame {
                Java.callStaticObject(testBars, barNavigation, .object(bar.reference)).map { Java.text($0) }
            }
            return (words == "Close").propValue
        default:
            return nil
        }
    }

    /// The application's name or mark on a sidebar's own `bar`: its title, the picture whose pixels its mark shows.
    private static func sidebarBarHolds(_ property: Prop, _ bar: AndroidBarView) -> HostValue? {
        if property == .barTitle {
            return Java.frame {
                Java.callStaticObject(testBars, barTitle, .object(bar.reference)).map { .string(Java.text($0)) }
            }
        }
        let shown = pictures.first { name in
            guard let picture = AndroidPictures.bitmap(.file(name)) else { return false }
            return Java.callStaticBool(testBars, barMarks, .object(bar.reference), .object(picture.reference))
        }
        return shown.map { .string($0) }
    }

    /// Whether the split view's sidebar's own bar shows the toggle at its end.
    static func sidebarBarOffersToggle(_ split: AndroidSplitView) -> Bool {
        Java.callStaticBool(testBars, barEndButton, .object(split.drawer.bar.reference))
    }

    private static let testBars = Java.findClass("stateui/android/test/TestBars")
    private static let barEndButton = Java.staticMethod(testBars, "endButton", "(Landroid/widget/Toolbar;)Z")
    private static let barTitle = Java.staticMethod(testBars, "title", "(Landroid/widget/Toolbar;)Ljava/lang/String;")
    private static let barMarks = Java.staticMethod(
        testBars, "marks", "(Landroid/widget/Toolbar;Landroid/graphics/Bitmap;)Z")
    private static let barNavigation = Java.staticMethod(
        testBars, "navigation", "(Landroid/widget/Toolbar;)Ljava/lang/String;")
    private static let barShown = Java.staticMethod(testBars, "shown", "(Landroid/widget/Toolbar;)Z")
    private static let barPressNavigation = Java.staticMethod(
        testBars, "pressNavigation", "(Landroid/widget/Toolbar;)Z")

    /// Presses the navigation button of the bar over `page`, as a touch does; false where it shows none.
    static func pressNavigation(over page: MountedElement) -> Bool {
        guard let stack = page.parent, stack.type == .navigationStack,
              let bar = ((stack.native as? AndroidElement)?.view as? AndroidNavigationView)?.bar
        else { return false }
        return Java.callStaticBool(testBars, barPressNavigation, .object(bar.reference))
    }
    private static let barTitled = Java.staticMethod(testBars, "titled", "(Landroid/widget/Toolbar;)Z")
    private static let barSubtitle = Java.staticMethod(
        testBars, "subtitle", "(Landroid/widget/Toolbar;)Ljava/lang/String;")
    private static let barBackground = Java.staticMethod(testBars, "background", "(Landroid/widget/Toolbar;)I")
    private static let barForeground = Java.staticMethod(testBars, "foreground", "(Landroid/widget/Toolbar;)I")
}
