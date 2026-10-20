// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import IOKit.ps
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIApple

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
    private var system: SystemWatch?

    init(core: CoreLink) {
        self.core = core
    }

    /// Lets go of all it watches: the power source holds it by an unretained pointer.
    isolated deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        appearanceWatch?.invalidate()
        if let powerSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .defaultMode) }
    }

    var powerSourceForTesting: CFRunLoopSource? { powerSource }

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

    /// Watches the locale, the battery, the network and the theme, each change reported through the runtime's step.
    func watch() {
        let center = NotificationCenter.default
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

        system = SystemWatch(
            localeChanged: { [weak self] in self?.changed { $0.reportLocale() } },
            networkChanged: { [weak self] reached in self?.changed { $0.core.setConnectivityInfo(reached) } })

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
        core.setAccentColor(Color(fractions: (
            Double(accent.redComponent), Double(accent.greenComponent), Double(accent.blueComponent),
            Double(accent.alphaComponent))))
    }

    /// The system's appearance: dark or light.
    func reportTheme() {
        let appearance = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        core.setColorScheme(appearance == .darkAqua ? .dark : .light)
    }

    /// The user's locale as it stands.
    func reportLocale() {
        core.setLocaleInfo(SystemFacts.locale)
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
