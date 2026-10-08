// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import GalleryUI
import StateUIAndroid

// listing: InteropActsSample.Android.swift
/// The acts the gallery performs on this head: its clipboard and its battery, asked of the device through the
/// gallery's own Java, com.stateui.gallery.GalleryDevice.
enum GalleryActs {
    /// Registers each act with the host. Said once, as the library loads.
    @MainActor
    static func register() {
        StateUIActs.add(GalleryContract.setClipboard) { text in
            Java.frame {
                Java.callStatic(Self.device, Self.copy, .object(StateUIAndroid.context), .object(Java.string(text)))
            }
        }

        StateUIActs.add(GalleryContract.readClipboard) {
            let text: String = Java.frame {
                Java.text(Java.callStaticObject(Self.device, Self.paste, .object(StateUIAndroid.context)))
            }
            return text
        }

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
    @MainActor private static let copy = Java.staticMethod(
        device, "copy", "(Landroid/content/Context;Ljava/lang/String;)V")
    @MainActor private static let paste = Java.staticMethod(
        device, "paste", "(Landroid/content/Context;)Ljava/lang/String;")
    @MainActor private static let batteryNow = Java.staticMethod(device, "battery", "(Landroid/content/Context;)[D")
}
// listing: end
