// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// What the device, its display, the application and the system's theme are, told to the core as the host
/// starts and whenever the activity's configuration changes.
/// Design: docs/design/platforms/android/runtime.md#the-environment
@MainActor
enum AndroidEnvironment {
    /// The smallest width, in density-independent pixels, from which a device is a tablet.
    static let tabletWidth: Float = 600

    /// Tells `core` what the activity `activity` stands on, each group of facts read in one call; a context that
    /// is no activity - a test's - stands in the light theme alone.
    static func report(to core: CoreLink, activity: jobject) {
        guard Java.jni.IsInstanceOf(Java.env, activity, JavaAPI.androidActivity) != 0 else {
            return core.setTheme(.light)
        }

        Java.frame {
            let device = Java.texts(Java.callStaticObject(JavaAPI.environment, JavaAPI.deviceFacts))
            let display = floats(Java.callStaticObject(JavaAPI.environment, JavaAPI.displayFacts, .object(activity)))
            let application = Java.texts(
                Java.callStaticObject(JavaAPI.environment, JavaAPI.applicationFacts, .object(activity)))
            guard device.count == 5, display.count == 7, application.count == 4 else { return }

            core.setDeviceInfo(HostDeviceInfo(
                formFactor: display[5] >= tabletWidth ? .tablet : .phone,
                platform: "Android",
                model: device[0],
                manufacturer: device[1],
                name: device[2],
                versionString: device[3],
                deviceType: device[4] == "1" ? .virtual : .physical))
            core.setDisplayInfo(HostDisplayInfo(
                width: Double(display[0]),
                height: Double(display[1]),
                density: Double(display[2]),
                orientation: display[0] >= display[1] ? .landscape : .portrait,
                rotation: [DisplayRotation.rotation0, .rotation90, .rotation180, .rotation270][Int(display[3]) & 3],
                refreshRate: Double(display[4])))
            core.setApplicationInfo(HostApplicationInfo(
                name: application[0], packageName: application[1],
                versionString: application[2], buildString: application[3]))
            core.setTheme(display[6] == 1 ? .dark : .light)
        }
    }

    private static func floats(_ array: jobject?) -> [Float] {
        guard let array else { return [] }

        let count = Int(Java.jni.GetArrayLength(Java.env, array))
        var values = [Float](repeating: 0, count: count)
        values.withUnsafeMutableBufferPointer {
            Java.jni.GetFloatArrayRegion(Java.env, array, 0, jsize(count), $0.baseAddress)
        }
        return values
    }
}
