// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The standard environment: what the host knows - the battery, the network,
// the display, the locale, the device, the app and the application's phase -
// as objects of `@State` properties every view resolves with `@Environment`.
// Design: docs/design/types/environment.md#the-standard-environment

/// The one instance of each standard provider, the scope every render starts
/// from, and the applier a host's push goes through.
/// Design: docs/design/types/environment.md#one-door-and-the-bottom-of-the-scope
enum StandardEnvironment {
    // Written by host pushes and read by builds, both on the UI thread.
    nonisolated(unsafe) static let battery = Battery()
    nonisolated(unsafe) static let connectivity = Connectivity()
    nonisolated(unsafe) static let display = DeviceDisplay()
    nonisolated(unsafe) static let locale = LocaleInfo()
    nonisolated(unsafe) static let device = DeviceInfo()
    nonisolated(unsafe) static let app = AppInfo()

    /// The application's session: one per process, its phase pushed by the host.
    nonisolated(unsafe) static let application = ApplicationSession()

    // The sessions a view outside every scene, window or page reads: a scene
    // always in front that opens nothing, a window that closes nothing, a page
    // nothing shows. Each scene, window and page offers its own, nearer.
    nonisolated(unsafe) static let scene = SceneSession()
    nonisolated(unsafe) static let window = WindowSession()
    nonisolated(unsafe) static let page = PageSession()

    /// What every render starts its scope with, keyed as `.environment()` keys.
    nonisolated(unsafe) static let scope: [(key: ObjectIdentifier, object: AnyObject)] = [
        (key: ObjectIdentifier(Battery.self), object: battery),
        (key: ObjectIdentifier(Connectivity.self), object: connectivity),
        (key: ObjectIdentifier(DeviceDisplay.self), object: display),
        (key: ObjectIdentifier(LocaleInfo.self), object: locale),
        (key: ObjectIdentifier(DeviceInfo.self), object: device),
        (key: ObjectIdentifier(AppInfo.self), object: app),
        (key: ObjectIdentifier(ApplicationSession.self), object: application),
        (key: ObjectIdentifier(SceneSession.self), object: scene),
        (key: ObjectIdentifier(WindowSession.self), object: window),
        (key: ObjectIdentifier(PageSession.self), object: page),
    ]

    /// The standard provider of a type, if there is one: what an unfilled
    /// `@Environment` slot answers, such as the application's, built outside
    /// any render.
    static func object(for key: ObjectIdentifier) -> AnyObject? {
        scope.last(where: { $0.key == key })?.object
    }

    /// Applies one decoded push. False for an unknown domain or a payload of
    /// the wrong shape, refused whole; an unknown member reads as `.unknown`.
    /// Design: docs/design/types/environment.md#a-push-is-refused-whole
    static func apply(domain: UInt8, values: [PropValue]) -> Bool {
        switch EnvironmentDomain(rawValue: domain) {
        case .battery:
            return applyBattery(values)
        case .connectivity:
            return applyConnectivity(values)
        case .display:
            return applyDisplay(values)
        case .locale:
            return applyLocale(values)
        case .device:
            return applyDevice(values)
        case .app:
            return applyApp(values)
        case .application:
            return applyApplication(values)
        case nil:
            return false
        }
    }

    private static func applyBattery(_ values: [PropValue]) -> Bool {
        guard values.count == 4,
              let level = values[0].number,
              let state = values[1].enumeration,
              let source = values[2].enumeration,
              let saver = values[3].enumeration
        else { return false }

        battery.chargeLevel = level
        battery.state = BatteryState(rawValue: state) ?? .unknown
        battery.powerSource = BatteryPowerSource(rawValue: source) ?? .unknown
        battery.energySaverStatus = EnergySaverStatus(rawValue: saver) ?? .unknown
        return true
    }

    private static func applyConnectivity(_ values: [PropValue]) -> Bool {
        // The profiles are members, so `.values` of `.enumeration`, not `.numbers`.
        guard values.count == 2,
              let access = values[0].enumeration,
              let profiles = values[1].values
        else { return false }

        connectivity.networkAccess = NetworkAccess(rawValue: access) ?? .unknown
        connectivity.connectionProfiles = profiles.map {
            $0.enumeration.flatMap(ConnectionProfile.init(rawValue:)) ?? .unknown
        }
        return true
    }

    private static func applyDisplay(_ values: [PropValue]) -> Bool {
        guard values.count == 6,
              let width = values[0].number,
              let height = values[1].number,
              let density = values[2].number,
              let orientation = values[3].enumeration,
              let rotation = values[4].enumeration,
              let refreshRate = values[5].number
        else { return false }

        display.width = width
        display.height = height
        display.density = density
        display.orientation = DisplayOrientation(rawValue: orientation) ?? .unknown
        display.rotation = DisplayRotation(rawValue: rotation) ?? .unknown
        display.refreshRate = refreshRate
        return true
    }

    private static func applyLocale(_ values: [PropValue]) -> Bool {
        guard values.count == 7,
              let language = values[0].string,
              let region = values[1].string,
              let name = values[2].string,
              let timeZone = values[3].string,
              let clock = values[4].bool,
              let firstDay = values[5].enumeration,
              let metric = values[6].bool
        else { return false }

        locale.language = language
        locale.region = region
        locale.name = name
        locale.timeZone = timeZone
        locale.uses24HourClock = clock
        locale.firstDayOfWeek = Weekday(rawValue: firstDay) ?? .sunday
        locale.isMetric = metric
        return true
    }

    private static func applyDevice(_ values: [PropValue]) -> Bool {
        guard values.count == 7,
              let formFactor = values[0].enumeration,
              let platform = values[1].string,
              let model = values[2].string,
              let manufacturer = values[3].string,
              let name = values[4].string,
              let versionString = values[5].string,
              let type = values[6].enumeration
        else { return false }

        device.formFactor = FormFactor(rawValue: formFactor) ?? .unknown
        device.platform = platform
        device.model = model
        device.manufacturer = manufacturer
        device.name = name
        device.versionString = versionString
        device.deviceType = DeviceType(rawValue: type) ?? .unknown
        return true
    }

    private static func applyApp(_ values: [PropValue]) -> Bool {
        guard values.count == 5,
              let name = values[0].string,
              let packageName = values[1].string,
              let versionString = values[2].string,
              let buildString = values[3].string,
              let theme = values[4].enumeration
        else { return false }

        app.name = name
        app.packageName = packageName
        app.versionString = versionString
        app.buildString = buildString
        app.requestedTheme = Theme(rawValue: theme) ?? .system
        return true
    }

    private static func applyApplication(_ values: [PropValue]) -> Bool {
        guard values.count == 1,
              let phase = values[0].enumeration.flatMap(ApplicationPhase.init(rawValue:))
        else { return false }

        application.phase = phase
        return true
    }
}
