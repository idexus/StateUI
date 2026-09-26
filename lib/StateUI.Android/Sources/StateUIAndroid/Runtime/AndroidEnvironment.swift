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
    /// The smallest width, in density-independent pixels, from which a device is a tablet.
    static let tabletWidth: Float = 600

    /// Tells `core` what the activity `activity` stands on, each group of facts read in one call; a context that
    /// is no activity - a test's - stands in the light theme alone.
    static func report(to core: CoreLink, activity: jobject) {
        reportChanging(to: core, context: activity)
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

    /// Tells `core` the user's locale, the battery and the network, as `context` reads them.
    static func reportChanging(to core: CoreLink, context: jobject) {
        Java.frame {
            let locale = Java.texts(Java.callStaticObject(JavaAPI.environment, JavaAPI.localeFacts, .object(context)))
            if locale.count == 8 {
                core.setLocaleInfo(HostLocaleInfo(
                    language: locale[0], region: locale[1], name: locale[2], timeZone: locale[3],
                    uses24HourClock: locale[4] == "1",
                    firstDayOfWeek: Weekday(rawValue: (Int32(locale[5]) ?? 1) - 1) ?? .sunday,
                    isMetric: locale[6] == "1",
                    layoutDirection: locale[7] == "1" ? .rightToLeft : .leftToRight))
            }

            let battery = floats(Java.callStaticObject(JavaAPI.environment, JavaAPI.batteryFacts, .object(context)))
            if battery.count == 4 { core.setBatteryInfo(batteryInfo(battery)) }

            let network = integers(
                Java.callStaticObject(JavaAPI.environment, JavaAPI.connectivityFacts, .object(context)))
            if network.count == 2 {
                let access: NetworkAccess = switch network[0] {
                case 1: .none
                case 2: .local
                case 3: .constrainedInternet
                case 4: .internet
                default: .unknown
                }
                let kinds: [(bit: Int32, profile: ConnectionProfile)] = [
                    (1, .bluetooth), (2, .cellular), (4, .ethernet), (8, .wiFi),
                ]
                core.setConnectivityInfo(HostConnectivityInfo(
                    networkAccess: access, connectionProfiles: kinds.filter { network[1] & $0.bit != 0 }.map(\.profile)))
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
