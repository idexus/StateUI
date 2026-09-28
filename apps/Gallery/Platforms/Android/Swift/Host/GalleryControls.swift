// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIAndroid

/// The controls this head realizes for the gallery's own elements, and each one's number, which its Java view tells
/// the Swift half by.
enum GalleryControls {
    /// Registers every control this host realizes. Said once, as the library loads.
    @MainActor
    static func register() {
        TrafficLightView.register()
        RatingBarView.register()
        GLESCube3DView.register()
    }

    /// Each control its Java view tells, by the number it was made with, held weakly.
    @MainActor private static var controls: [Int64: Weak] = [:]
    @MainActor private static var last: Int64 = 0

    /// The next number, for a control about to make its view.
    @MainActor
    static func reserve() -> Int64 {
        last += 1
        return last
    }

    /// Holds `control` under `number` for its view's calls, weakly.
    @MainActor
    static func hold(_ control: AnyObject, as number: Int64) {
        controls[number] = Weak(object: control)
    }

    /// Lets go of the control under `number`.
    @MainActor
    static func forget(_ number: Int64) {
        controls[number] = nil
    }

    /// The live control under `number`; nil once it has gone.
    @MainActor
    static func control(_ number: Int64) -> AnyObject? {
        controls[number]?.object
    }

    private struct Weak {
        weak var object: AnyObject?
    }
}
