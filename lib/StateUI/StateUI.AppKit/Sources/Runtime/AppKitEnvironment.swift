// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import IOKit.ps
import Network
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The user's locale, the battery, the network, the theme and the accent, told to the core as the host starts and
/// whenever one changes, for as long as the application runs.
/// Design: docs/design/platforms/appkit/runtime.md#the-environment
@MainActor
final class AppKitEnvironment {
    private let core: CoreLink

    /// How a change is reported: what the report tells the core, run as the runtime's step for a change of what
    /// the application stands on.
    private var reportChange: (() -> Void) -> Void = { $0() }

    private var observers: [NSObjectProtocol] = []
    private var appearanceWatch: NSKeyValueObservation?
    private var powerSource: CFRunLoopSource?
    private var network: NWPathMonitor?

    init(core: CoreLink) {
        self.core = core
    }

    /// Tells the core the locale, the battery, the theme and the accent as they stand, then each change through
    /// `reportingChanges` - the network as its monitor answers.
    func start(reportingChanges: @escaping (() -> Void) -> Void) {
        reportLocale()
        reportBattery()
        reportTheme()
        reportAccent()
        reportChange = reportingChanges
        watch()
    }

    private func watch() {
        let center = NotificationCenter.default
        let localeChanges: [Notification.Name] = [NSLocale.currentLocaleDidChangeNotification, .NSSystemTimeZoneDidChange]
        for name in localeChanges {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.changed { $0.reportLocale() } }
            })
        }
        observers.append(center.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.changed { $0.reportBattery() } }
        })

        // A C callback carries no capture: the environment rides in the context pointer; the renderer keeps it.
        let notify: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let environment = Unmanaged<AppKitEnvironment>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { environment.changed { $0.reportBattery() } }
        }
        if let source = IOPSNotificationCreateRunLoopSource(notify, Unmanaged.passUnretained(self).toOpaque())?
            .takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            powerSource = source
        }

        let network = NWPathMonitor()
        network.pathUpdateHandler = { [weak self] path in
            MainActor.assumeIsolated { self?.changed { $0.report(path) } }
        }
        network.start(queue: .main)
        self.network = network

        watchTheme()
    }

    /// Reports the theme and the accent, then each change of them as it comes, through `reportingChanges` - alone,
    /// where a host watches nothing else of its machine.
    func startTheme(reportingChanges: @escaping (() -> Void) -> Void) {
        reportTheme()
        reportAccent()
        reportChange = reportingChanges
        watchTheme()
    }

    private func watchTheme() {
        appearanceWatch = NSApplication.shared.observe(\.effectiveAppearance) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.changed { $0.reportTheme(); $0.reportAccent() } }
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSColor.systemColorsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.changed { $0.reportAccent() } }
        })
    }

    /// Reports a change through the runtime's step for it.
    private func changed(_ report: @escaping (AppKitEnvironment) -> Void) {
        reportChange { report(self) }
    }

    /// The accent the user chose, as the application's appearance draws it.
    func reportAccent() {
        var accent = NSColor.systemBlue
        NSApplication.shared.effectiveAppearance.performAsCurrentDrawingAppearance {
            accent = NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? .systemBlue
        }
        func channel(_ value: CGFloat) -> Int { Int((value * 255).rounded()) }
        core.setAccentColor(Color(
            red: channel(accent.redComponent), green: channel(accent.greenComponent),
            blue: channel(accent.blueComponent), alpha: channel(accent.alphaComponent)))
    }

    /// The system's appearance: dark or light.
    func reportTheme() {
        let appearance = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        core.setColorScheme(appearance == .darkAqua ? .dark : .light)
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
    }

    func reportBattery() {
        let saving = ProcessInfo.processInfo.isLowPowerModeEnabled
        let battery = Self.internalBattery()
        let current = battery?[kIOPSCurrentCapacityKey] as? Double ?? 0
        let maximum = battery?[kIOPSMaxCapacityKey] as? Double ?? 0
        core.setBatteryInfo(HostBatteryInfo(
            present: battery != nil, level: maximum > 0 ? current / maximum : 0,
            charging: battery?[kIOPSIsChargingKey] as? Bool ?? false,
            onMains: battery.map { $0[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue } ?? true,
            full: battery?[kIOPSIsChargedKey] as? Bool ?? false, saving: saving))
    }

    private func report(_ path: NWPath) {
        let access: NetworkAccess = switch path.status {
        case .satisfied: .internet
        case .unsatisfied: path.availableInterfaces.isEmpty ? .none : .local
        case .requiresConnection: .none
        @unknown default: .unknown
        }
        let kinds: [(NWInterface.InterfaceType, ConnectionProfile)] = [
            (.cellular, .cellular), (.wiredEthernet, .ethernet), (.wifi, .wifi),
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
