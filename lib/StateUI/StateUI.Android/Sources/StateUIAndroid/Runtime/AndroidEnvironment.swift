// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// What the device, its display, the application and the system's theme are, told to the core as the host
/// starts and whenever the activity's configuration changes; the locale, the battery and the network whenever one
/// changes too.
/// Design: docs/design/platforms/android/runtime.md#the-environment
@MainActor
enum AndroidEnvironment {
    /// Tells `core` what the activity `activity` stands on, each group of facts read in one call; a context that
    /// is no activity - a test's - stands in the light theme alone.
    static func report(to core: CoreLink, activity: jobject) {
        reportChanging(to: core, context: activity)
        guard Java.jni.IsInstanceOf(Java.env, activity, JavaAPI.androidActivity) != 0 else {
            return core.setColorScheme(.light)
        }

        Java.frame {
            let device = Java.texts(Java.callStaticObject(JavaAPI.environment, JavaAPI.deviceFacts, .object(activity)))
            let display = floats(Java.callStaticObject(JavaAPI.environment, JavaAPI.displayFacts, .object(activity)))
            let application = Java.texts(
                Java.callStaticObject(JavaAPI.environment, JavaAPI.applicationFacts, .object(activity)))
            guard display.count == 7, application.count == 4, let device = HostDeviceInfo(
                words: device, formFactor: .touchScreen(smallestWidth: Double(display[5])), platform: "Android")
            else { return }

            core.setDeviceInfo(device)
            core.setDisplayInfo(HostDisplayInfo(
                width: Double(display[0]), height: Double(display[1]), density: Double(display[2]),
                quarterTurns: Int(display[3]), refreshRate: Double(display[4])))
            core.setApplicationInfo(HostApplicationInfo(
                name: application[0], packageName: application[1],
                versionString: application[2], buildString: application[3]))
            core.setColorScheme(display[6] == 1 ? .dark : .light)
        }
    }

    /// Tells `core` the user's locale, the battery and the network, as `context` reads them.
    static func reportChanging(to core: CoreLink, context: jobject) {
        Java.frame {
            let locale = Java.texts(Java.callStaticObject(JavaAPI.environment, JavaAPI.localeFacts, .object(context)))
            if let locale = HostLocaleInfo(words: locale) { core.setLocaleInfo(locale) }

            let battery = floats(Java.callStaticObject(JavaAPI.environment, JavaAPI.batteryFacts, .object(context)))
            if battery.count == 4 { core.setBatteryInfo(batteryInfo(battery)) }

            let network = integers(
                Java.callStaticObject(JavaAPI.environment, JavaAPI.connectivityFacts, .object(context)))
            if network.count == 2 {
                core.setConnectivityInfo(HostConnectivityInfo(access: network[0], connections: network[1]))
            }
        }
    }

    /// The battery as `StateUIEnvironment.battery` reads it: a charge, `BatteryManager`'s status and plug.
    private static func batteryInfo(_ facts: [Float]) -> HostBatteryInfo {
        let saver: EnergySaverStatus = facts[3] == 1 ? .on : .off
        guard facts[0] >= 0 else {
            return HostBatteryInfo(chargeLevel: 1, state: .notPresent, powerSource: .ac, energySaverStatus: saver)
        }

        let state: BatteryState = switch Int(facts[1]) {
        case 2: .charging
        case 3: .discharging
        case 4: .notCharging
        case 5: .full
        default: .unknown
        }
        let source: BatteryPowerSource = switch Int(facts[2]) {
        case 0: .battery
        case 2: .usb
        case 4: .wireless
        default: .ac
        }
        return HostBatteryInfo(
            chargeLevel: Double(facts[0]), state: state, powerSource: source, energySaverStatus: saver)
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

    private static func integers(_ array: jobject?) -> [Int32] {
        guard let array else { return [] }

        let count = Int(Java.jni.GetArrayLength(Java.env, array))
        var values = [Int32](repeating: 0, count: count)
        values.withUnsafeMutableBufferPointer {
            Java.jni.GetIntArrayRegion(Java.env, array, 0, jsize(count), $0.baseAddress)
        }
        return values
    }
}
