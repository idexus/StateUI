// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import IOKit.ps
import Network
@_spi(Host) import StateUI

/// The user's locale, the battery and the network, told to the core as the host starts and whenever one changes,
/// for as long as the application runs.
/// Design: docs/design/platforms/appkit/runtime.md#the-environment
@MainActor
final class AppKitEnvironment {
    private let core: CoreLink

    /// Called after each locale report, so the tree follows the language's direction.
    var localeReported: () -> Void = {}

    private var observers: [NSObjectProtocol] = []
    private var powerSource: CFRunLoopSource?
    private var network: NWPathMonitor?

    init(core: CoreLink) {
        self.core = core
    }

    /// Reports all three, then watches each for a change.
    func start() {
        reportLocale()
        reportBattery()
        watch()
    }

    private func watch() {
        let center = NotificationCenter.default
        let localeChanges: [Notification.Name] = [NSLocale.currentLocaleDidChangeNotification, .NSSystemTimeZoneDidChange]
        for name in localeChanges {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reportLocale() }
            })
        }
        observers.append(center.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reportBattery() }
        })

        // A C callback carries no capture: the environment rides in the context pointer; the renderer keeps it.
        let notify: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let environment = Unmanaged<AppKitEnvironment>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { environment.reportBattery() }
        }
        if let source = IOPSNotificationCreateRunLoopSource(notify, Unmanaged.passUnretained(self).toOpaque())?
            .takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            powerSource = source
        }

        let network = NWPathMonitor()
        network.pathUpdateHandler = { [weak self] path in
            MainActor.assumeIsolated { self?.report(path) }
        }
        network.start(queue: .main)
        self.network = network
    }

    func reportLocale() {
        let locale = Locale.current
        let language = locale.language.languageCode?.identifier ?? ""
        let hourCycle = locale.hourCycle
        core.setLocaleInfo(HostLocaleInfo(
            language: language,
            region: locale.region?.identifier ?? "",
            name: locale.identifier(.bcp47),
            timeZone: TimeZone.current.identifier,
            uses24HourClock: hourCycle == .zeroToTwentyThree || hourCycle == .oneToTwentyFour,
            firstDayOfWeek: Weekday(rawValue: Int32(Calendar.current.firstWeekday - 1)) ?? .sunday,
            isMetric: locale.measurementSystem != .us,
            layoutDirection: locale.language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight))
        localeReported()
    }

    func reportBattery() {
        let saver: EnergySaverStatus = ProcessInfo.processInfo.isLowPowerModeEnabled ? .on : .off
        guard let battery = Self.internalBattery() else {
            return core.setBatteryInfo(HostBatteryInfo(
                chargeLevel: 1, state: .notPresent, powerSource: .ac, energySaverStatus: saver))
        }

        let current = battery[kIOPSCurrentCapacityKey] as? Double ?? 0
        let maximum = battery[kIOPSMaxCapacityKey] as? Double ?? 0
        let onMains = battery[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
        let charging = battery[kIOPSIsChargingKey] as? Bool ?? false
        let charged = battery[kIOPSIsChargedKey] as? Bool ?? false
        let state: BatteryState = charging ? .charging : !onMains ? .discharging : charged ? .full : .notCharging
        core.setBatteryInfo(HostBatteryInfo(
            chargeLevel: maximum > 0 ? min(max(current / maximum, 0), 1) : 0,
            state: state,
            powerSource: onMains ? .ac : .battery,
            energySaverStatus: saver))
    }

    private func report(_ path: NWPath) {
        let access: NetworkAccess = switch path.status {
        case .satisfied: .internet
        case .unsatisfied: path.availableInterfaces.isEmpty ? .none : .local
        case .requiresConnection: .none
        @unknown default: .unknown
        }
        let kinds: [(NWInterface.InterfaceType, ConnectionProfile)] = [
            (.cellular, .cellular), (.wiredEthernet, .ethernet), (.wifi, .wiFi),
        ]
        core.setConnectivityInfo(HostConnectivityInfo(
            networkAccess: access,
            connectionProfiles: kinds.filter { kind in path.availableInterfaces.contains { $0.type == kind.0 } }
                .map(\.1)))
    }

    /// The description of the machine's own battery, nil on a machine with none.
    private static func internalBattery() -> [String: Any]? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        return sources.lazy
            .compactMap { IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any] }
            .first { $0[kIOPSTypeKey] as? String == kIOPSInternalBatteryType }
    }
}

#endif
