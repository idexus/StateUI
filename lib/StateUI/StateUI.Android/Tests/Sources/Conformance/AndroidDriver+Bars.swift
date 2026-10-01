// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import CStateUIAndroid
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
@_spi(Host) import StateUIConformance

/// What the Android driver reads of the bar an arrangement declares: Android's toolbar over the page it shows - the
/// line under its title and the colour it is painted.
extension AndroidDriver {
    /// `property` of the bar the page `element` shows stands under; nil where no stack gives that page a bar.
    static func barHolds(_ property: Prop, of element: MountedElement) -> HostValue? {
        var each = element.visiblePage
        while let found = each, found.type != .navigationStack { each = found.parent }
        guard let bar = ((each?.native as? AndroidElement)?.view as? AndroidNavigationView)?.bar else { return nil }
        switch property {
        case .barSubtitle:
            return Java.frame {
                Java.callStaticObject(testBars, barSubtitle, .object(bar.reference)).map { .string(Java.text($0)) }
            }
        case .barBackgroundColor:
            let argb = UInt32(bitPattern: Java.callStaticInt(testBars, barBackground, .object(bar.reference)))
            guard argb != 0 else { return nil }
            return .color(
                red: UInt8(argb >> 16 & 0xFF), green: UInt8(argb >> 8 & 0xFF), blue: UInt8(argb & 0xFF),
                alpha: UInt8(argb >> 24))
        default:
            return nil
        }
    }

    private static let testBars = Java.findClass("stateui/android/test/TestBars")
    private static let barSubtitle = Java.staticMethod(
        testBars, "subtitle", "(Landroid/widget/Toolbar;)Ljava/lang/String;")
    private static let barBackground = Java.staticMethod(testBars, "background", "(Landroid/widget/Toolbar;)I")
}
