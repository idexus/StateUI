// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CGalleryWinUI
import GalleryUI
import StateUIWinUI

/// The gallery's own controls, as this host realizes them.
///
/// The contracts and the Swift halves are shared by every host - see Sources/Samples/Interop. What each control IS
/// on screen is its element's, made by the gallery's relay in Platforms/WinUI/Relay, and so is its registration:
/// `register()` at the end of the control's own file. This is the list of them, and what the relay tells them by.
enum GalleryControls {
    /// Registers every control this host realizes, and hands the relay what it tells. Said once, before the
    /// application runs.
    @MainActor
    static func register() {
        var told = GalleryWinUICallbacks(
            lampTapped: { control, lamp in
                MainActor.assumeIsolated { (GalleryControls.control(control) as? TrafficLightControl)?.tapped(Int(lamp)) }
            },
            rated: { control, rating in
                MainActor.assumeIsolated { (GalleryControls.control(control) as? RatingBarControl)?.rated(rating) }
            })
        gallery_winui_set_callbacks(&told)
        TrafficLightControl.register()
        RatingBarControl.register()
        Direct3DCube3DControl.register()
    }

    /// Each control the relay tells, by the number it was made with, held weakly.
    @MainActor private static var controls: [Int64: Weak] = [:]
    @MainActor private static var last: Int64 = 0

    /// The next number, for a control about to make its element.
    @MainActor
    static func reserve() -> Int64 {
        last += 1
        return last
    }

    /// Holds `control` under `number` for the relay's callbacks, weakly.
    @MainActor
    static func hold(_ control: AnyObject, as number: Int64) {
        controls[number] = Weak(object: control)
    }

    /// Forgets the control of `number`, which left.
    @MainActor
    static func forget(_ number: Int64) {
        controls[number] = nil
    }

    /// The control of `number`; nil once it left.
    @MainActor
    private static func control(_ number: Int64) -> AnyObject? {
        controls[number]?.object
    }

    private struct Weak {
        weak var object: AnyObject?
    }
}
