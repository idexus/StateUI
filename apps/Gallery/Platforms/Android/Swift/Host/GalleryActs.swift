// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import GalleryUI
import StateUIAndroid

// listing: InteropActsSample.Android.swift
/// The acts the gallery performs on this head: its log and its battery, asked of the device through the gallery's
/// own Java, com.stateui.gallery.GalleryDevice.
enum GalleryActs {
    /// Registers each act with the host. Said once, as the library loads.
    @MainActor
    static func register() {
        // listing: android.md.acts
        StateUIActs.add(GalleryContract.log) { line in
            Java.frame { Java.callStatic(Self.device, Self.log, .object(Java.string(line))) }
        }
        // listing: end

        StateUIActs.add(GalleryContract.batteryLevel) {
            // The sticky ACTION_BATTERY_CHANGED, read in GalleryDevice.java.
            battery()
        }
    }

    /// The battery's level, 0 to 1 - 0 where the device has none - and whether it charges.
    @MainActor
    static func battery() -> (Double, Bool) {
        let reading = Java.frame { () -> [Double] in
            var values = [0.0, 0.0]
            guard let array = Java.callStaticObject(Self.device, Self.batteryNow, .object(StateUIAndroid.context))
            else { return values }
            values.withUnsafeMutableBufferPointer { Java.jni.GetDoubleArrayRegion(Java.env, array, 0, 2, $0.baseAddress) }
            return values
        }
        return (reading[0], reading[1] != 0)
    }

    @MainActor private static let device = Java.findClass("com/stateui/gallery/GalleryDevice")
    @MainActor private static let log = Java.staticMethod(device, "log", "(Ljava/lang/String;)V")
    @MainActor private static let batteryNow = Java.staticMethod(device, "battery", "(Landroid/content/Context;)[D")
}
// listing: end
