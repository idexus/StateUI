// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import Network
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The theme, the user's locale, the battery and the network, told to the core as the host starts and whenever one
/// changes, for as long as the application runs.
/// Design: docs/design/platforms/uikit/runtime.md#the-environment
@MainActor
final class UIKitEnvironment {
    private let core: CoreLink

    /// How a change is reported: what the report tells the core, run as the runtime's step for a change of what
    /// the application stands on.
    private var reportChange: (() -> Void) -> Void = { $0() }

    private var observers: [NSObjectProtocol] = []
    private var network: NWPathMonitor?
    private var watchedScene: (any UITraitChangeRegistration)?

    init(core: CoreLink) {
        self.core = core
    }

    /// Tells the core what stands now, then each change as it comes, through `reportingChanges`.
    func start(reportingChanges: @escaping (() -> Void) -> Void) {
        reportLocale()
        reportBattery()
        reportChange = reportingChanges
        watch()
    }

    /// Follows the theme of `scene`, the first iOS connected: what it stands in now, then each change - the
    /// theme is the whole application's, which every scene follows alike.
    func followTheme(of scene: UIWindowScene) {
        guard watchedScene == nil else { return }
        reportChange { self.reportTheme(scene.traitCollection.userInterfaceStyle) }
        watchedScene = scene.registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
            [weak self] (scene: UIWindowScene, _: UITraitCollection) in
            self?.changed { $0.reportTheme(scene.traitCollection.userInterfaceStyle) }
        }
    }

    /// Stops following the theme of the scene it followed, which stays.
    func stopFollowingTheme(of scene: UIWindowScene) {
        guard let watchedScene else { return }
        scene.unregisterForTraitChanges(watchedScene)
        self.watchedScene = nil
    }

    private func watch() {
        let center = NotificationCenter.default
        for name in [NSLocale.currentLocaleDidChangeNotification, .NSSystemTimeZoneDidChange] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.changed { $0.reportLocale() } }
            })
        }
        for name in [
            UIDevice.batteryLevelDidChangeNotification, UIDevice.batteryStateDidChangeNotification,
            .NSProcessInfoPowerStateDidChange,
        ] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.changed { $0.reportBattery() } }
            })
        }

        let network = NWPathMonitor()
        network.pathUpdateHandler = { [weak self] path in
            MainActor.assumeIsolated { self?.changed { $0.report(path) } }
        }
        network.start(queue: .main)
        self.network = network
    }

    /// Reports a change through the runtime's step for it.
    private func changed(_ report: @escaping (UIKitEnvironment) -> Void) {
        reportChange { report(self) }
    }

    /// The theme a scene stands in: dark, else light.
    func reportTheme(_ style: UIUserInterfaceStyle) {
        core.setColorScheme(style == .dark ? .dark : .light)
    }

    func reportLocale() {
        let locale = Locale.current
        let hourCycle = locale.hourCycle
        core.setLocaleInfo(HostLocaleInfo(
            language: locale.language.languageCode?.identifier ?? "",
            region: locale.region?.identifier ?? "",
            name: locale.identifier(.bcp47),
            timeZone: TimeZone.current.identifier,
            uses24HourClock: hourCycle == .zeroToTwentyThree || hourCycle == .oneToTwentyFour,
            firstDayOfWeek: Weekday(rawValue: Int32(Calendar.current.firstWeekday - 1)) ?? .sunday,
            isMetric: locale.measurementSystem != .us,
            layoutDirection: locale.language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight))
    }

    /// The device's battery; one UIKit knows nothing of - the simulator's - is none.
    func reportBattery() {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let state = device.batteryState
        core.setBatteryInfo(HostBatteryInfo(
            present: state != .unknown, level: Double(device.batteryLevel), charging: state == .charging,
            onMains: state != .unplugged, full: state == .full,
            saving: ProcessInfo.processInfo.isLowPowerModeEnabled))
    }

    /// The screen `scene` stands on, as it is turned now.
    func reportDisplay(of scene: UIWindowScene) {
        let screen = scene.screen
        let turns: Int = switch scene.effectiveGeometry.interfaceOrientation {
        case .landscapeRight: 1
        case .portraitUpsideDown: 2
        case .landscapeLeft: 3
        default: 0
        }
        core.setDisplayInfo(HostDisplayInfo(
            width: screen.bounds.width * screen.nativeScale, height: screen.bounds.height * screen.nativeScale,
            density: screen.nativeScale, quarterTurns: turns, refreshRate: Double(screen.maximumFramesPerSecond)))
    }

    /// The screen turned, or the scene moved to another.
    func displayMoved(for scene: UIWindowScene) {
        changed { $0.reportDisplay(of: scene) }
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
}
#endif
