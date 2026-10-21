// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIApple

/// The theme, the accent, the user's locale, the battery, the network, the display and the accessibility settings,
/// told to the core as the host starts - the theme and the accent as the first scene connects, the display as each does - and whenever one
/// changes, for as long as the application runs.
/// Design: docs/design/platforms/uikit/runtime.md#the-environment
@MainActor
final class UIKitEnvironment {
    private let core: CoreLink

    /// How a change is reported: what the report tells the core, run as the runtime's step for a change of what
    /// the application stands on.
    private var reportChange: (() -> Void) -> Void = { $0() }

    private var observers: [NSObjectProtocol] = []
    private var system: SystemWatch?
    private weak var themeScene: UIWindowScene?
    private var themeWatch: (any UITraitChangeRegistration)?

    init(core: CoreLink) {
        self.core = core
    }

    /// Tells the core what stands now, then each change as it comes, through `reportingChanges`.
    func start(reportingChanges: @escaping (() -> Void) -> Void) {
        reportLocale()
        reportBattery()
        reportAccessibility()
        reportChange = reportingChanges
        watch()
    }

    /// Follows the theme of `scene` where no scene iOS holds is followed: what it stands in now, then each change -
    /// the theme is the whole application's, which every scene follows alike.
    func followTheme(of scene: UIWindowScene) {
        guard themeScene == nil else { return }
        themeScene = scene
        reportChange {
            self.reportTheme(scene.traitCollection.userInterfaceStyle)
            self.reportAccent(scene.traitCollection)
        }
        themeWatch = scene.registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
            [weak self] (scene: UIWindowScene, _: UITraitCollection) in
            self?.changed {
                $0.reportTheme(scene.traitCollection.userInterfaceStyle)
                $0.reportAccent(scene.traitCollection)
            }
        }
    }

    /// Stops following the theme of `scene`, where it is the one followed: iOS let go of it, or a test's host ends.
    func stopFollowingTheme(of scene: UIWindowScene) {
        guard scene === themeScene, let themeWatch else { return }
        scene.unregisterForTraitChanges(themeWatch)
        self.themeWatch = nil
        themeScene = nil
    }

    var followedSceneForTesting: UIWindowScene? { themeScene }

    private func watch() {
        let center = NotificationCenter.default
        for name in [
            UIDevice.batteryLevelDidChangeNotification, UIDevice.batteryStateDidChangeNotification,
            .NSProcessInfoPowerStateDidChange,
        ] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.changed { $0.reportBattery() } }
            })
        }
        for name in [
            UIAccessibility.reduceMotionStatusDidChangeNotification,
            UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            UIAccessibility.voiceOverStatusDidChangeNotification, UIContentSizeCategory.didChangeNotification,
        ] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.changed { $0.reportAccessibility() } }
            })
        }
        system = SystemWatch(
            localeChanged: { [weak self] in self?.changed { $0.reportLocale() } },
            networkChanged: { [weak self] reached in self?.changed { $0.core.setConnectivityInfo(reached) } })
    }

    /// Reports a change through the runtime's step for it.
    private func changed(_ report: @escaping (UIKitEnvironment) -> Void) {
        reportChange { report(self) }
    }

    /// The application's tint as `traits` draw it: iOS has no accent of the user's, so an application's own stands
    /// in its place.
    func reportAccent(_ traits: UITraitCollection) {
        var (red, green, blue, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        UIColor.tintColor.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        core.setAccentColor(Color(fractions: (Double(red), Double(green), Double(blue), Double(alpha))))
    }

    /// The theme a scene stands in: dark, else light.
    func reportTheme(_ style: UIUserInterfaceStyle) {
        core.setColorScheme(style == .dark ? .dark : .light)
    }

    /// The user's locale as it stands.
    func reportLocale() {
        core.setLocaleInfo(SystemFacts.locale)
    }

    /// The user's accessibility settings: less motion, darker colours for more contrast, VoiceOver, and the scale of
    /// words as the size the user chose draws the body's 17 points.
    func reportAccessibility() {
        let chosen = UITraitCollection(preferredContentSizeCategory: UIApplication.shared.preferredContentSizeCategory)
        core.setAccessibilityInfo(HostAccessibilityInfo(
            reducesMotion: UIAccessibility.isReduceMotionEnabled,
            prefersHigherContrast: UIAccessibility.isDarkerSystemColorsEnabled,
            isScreenReaderOn: UIAccessibility.isVoiceOverRunning,
            textScale: UIFontMetrics(forTextStyle: .body).scaledValue(for: 17, compatibleWith: chosen) / 17))
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
}
#endif
