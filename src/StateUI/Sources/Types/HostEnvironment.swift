// The STANDARD ENVIRONMENT: what the host knows, provided to every tree.
//
// The battery, the network, the display, the locale, the device, the app and
// the window's phase are all state the HOST holds and this side can only be
// told about. Each is a `@StateClass` object the differ seeds into the scope
// of every walk, so any view resolves it the way it resolves an object an
// ancestor provided:
//
//     struct SaveButton: ContentView {
//         @Environment var connectivity: Connectivity
//
//         var content: Element {
//             Button("Save").isEnabled(connectivity.networkAccess == .internet)
//         }
//     }
//
// Nothing is registered and nothing is passed down - the type is the key, the
// standard rule. The objects live for the process; the C# side pushes their
// values through `stateui_set_environment` - once before the first render,
// so the first tree already knows, and again whenever a platform event says
// something moved. A write lands through the `@StateClass` accessors, so
// exactly the views that READ the changed object are rebuilt, and a view that
// reads none of this costs nothing.
//
// A test - or an app that wants to lie to one branch - provides a fake with
// the ordinary modifier, and the nearer object wins:
//
//     let fake = Battery()
//     fake.chargeLevel = 0.07
//     ChildView().environment(fake)
//
// THE NUMBERS THESE ENUMS CARRY ARE OURS, the wire's rule (Types/Enums.swift):
// declaration order from 0, written out case by case, crossing as
// `.enumeration` and translated onto the MAUI member each case's `///` names by
// a mirror on the far side - `SwiftBatteryState` and its neighbours in
// SwiftWireEnums.cs, checked case for case by `WireEnumTests`. MAUI's own
// numbers stay out of it: they are MAUI's internal business, and a release that
// renumbered one would have every report here read as a different member, with
// nothing failing anywhere. `Weekday` is .NET's DayOfWeek rather than MAUI's and
// takes the same treatment, as does anything MAUI keeps as a struct compared by
// value (DeviceIdiom) or does not have at all (WindowPhase).

/// How the battery is doing. MAUI: BatteryState - Microsoft.Maui.Devices.
public enum BatteryState: Int32, Sendable {
    /// The host has not said. MAUI: BatteryState.Unknown.
    case unknown = 0

    /// Plugged in and charging. MAUI: BatteryState.Charging.
    case charging = 1

    /// Running on the battery. MAUI: BatteryState.Discharging.
    case discharging = 2

    /// Plugged in and full. MAUI: BatteryState.Full.
    case full = 3

    /// Plugged in and not charging - a battery held at a limit, or resting.
    /// MAUI: BatteryState.NotCharging.
    case notCharging = 4

    /// There is no battery in this machine. MAUI: BatteryState.NotPresent.
    case notPresent = 5
}

/// Where the power is coming from. MAUI: BatteryPowerSource.
public enum BatteryPowerSource: Int32, Sendable {
    /// The host has not said. MAUI: BatteryPowerSource.Unknown.
    case unknown = 0

    /// The battery itself. MAUI: BatteryPowerSource.Battery.
    case battery = 1

    /// A charger in the wall. MAUI: BatteryPowerSource.AC.
    case ac = 2

    /// A USB port. MAUI: BatteryPowerSource.Usb.
    case usb = 3

    /// A wireless pad. MAUI: BatteryPowerSource.Wireless.
    case wireless = 4
}

/// Whether the platform's battery saver is on. MAUI: EnergySaverStatus.
public enum EnergySaverStatus: Int32, Sendable {
    /// The host has not said. MAUI: EnergySaverStatus.Unknown.
    case unknown = 0

    /// The saver is on - a good moment to do less. MAUI: EnergySaverStatus.On.
    case on = 1

    /// The saver is off. MAUI: EnergySaverStatus.Off.
    case off = 2
}

/// What the network can reach. MAUI: NetworkAccess - Microsoft.Maui.Networking.
public enum NetworkAccess: Int32, Sendable {
    /// The host has not said. MAUI: NetworkAccess.Unknown.
    case unknown = 0

    /// No network at all. MAUI: NetworkAccess.None.
    case none = 1

    /// The local network only, no route out. MAUI: NetworkAccess.Local.
    case local = 2

    /// The internet, behind a portal or a limit - reachable but constrained.
    /// MAUI: NetworkAccess.ConstrainedInternet.
    case constrainedInternet = 3

    /// The internet. MAUI: NetworkAccess.Internet.
    case internet = 4
}

/// One way the device is connected. MAUI: ConnectionProfile.
public enum ConnectionProfile: Int32, Sendable {
    /// A kind this library has no name for. MAUI: ConnectionProfile.Unknown.
    case unknown = 0

    /// Bluetooth. MAUI: ConnectionProfile.Bluetooth.
    case bluetooth = 1

    /// A mobile data connection. MAUI: ConnectionProfile.Cellular.
    case cellular = 2

    /// A wired network. MAUI: ConnectionProfile.Ethernet.
    case ethernet = 3

    /// Wi-Fi. MAUI: ConnectionProfile.WiFi.
    case wiFi = 4
}

/// Which way the screen is turned, coarsely. MAUI: DisplayOrientation.
public enum DisplayOrientation: Int32, Sendable {
    /// The host has not said - a desktop usually answers this.
    /// MAUI: DisplayOrientation.Unknown.
    case unknown = 0

    /// Taller than wide. MAUI: DisplayOrientation.Portrait.
    case portrait = 1

    /// Wider than tall. MAUI: DisplayOrientation.Landscape.
    case landscape = 2
}

/// How far the screen is rotated from its natural position. MAUI:
/// DisplayRotation.
public enum DisplayRotation: Int32, Sendable {
    /// The host has not said. MAUI: DisplayRotation.Unknown.
    case unknown = 0

    /// Not rotated. MAUI: DisplayRotation.Rotation0.
    case rotation0 = 1

    /// A quarter turn. MAUI: DisplayRotation.Rotation90.
    case rotation90 = 2

    /// Upside down. MAUI: DisplayRotation.Rotation180.
    case rotation180 = 3

    /// Three quarters. MAUI: DisplayRotation.Rotation270.
    case rotation270 = 4
}

/// Which look the system asked for. MAUI: AppTheme -
/// Microsoft.Maui.ApplicationModel.
public enum AppTheme: Int32, Sendable {
    /// The system did not say. MAUI: AppTheme.Unspecified.
    case unspecified = 0

    /// Light. MAUI: AppTheme.Light.
    case light = 1

    /// Dark. MAUI: AppTheme.Dark.
    case dark = 2
}

/// Whether this is real hardware. MAUI: DeviceType.
public enum DeviceType: Int32, Sendable {
    /// The host has not said. MAUI: DeviceType.Unknown.
    case unknown = 0

    /// A physical device. MAUI: DeviceType.Physical.
    case physical = 1

    /// An emulator or a simulator. MAUI: DeviceType.Virtual.
    case virtual = 2
}

/// The first day of a calendar week - what `LocaleInfo.firstDayOfWeek`
/// answers. .NET: DayOfWeek, whose numbers these are NOT: the days are
/// numbered here like every other closed vocabulary, and the host translates
/// each onto the DayOfWeek member named below it. That the two lists happen to
/// agree today is a coincidence and not a contract.
public enum Weekday: Int32, Sendable {
    /// Sunday. .NET: DayOfWeek.Sunday.
    case sunday = 0

    /// Monday. .NET: DayOfWeek.Monday.
    case monday = 1

    /// Tuesday. .NET: DayOfWeek.Tuesday.
    case tuesday = 2

    /// Wednesday. .NET: DayOfWeek.Wednesday.
    case wednesday = 3

    /// Thursday. .NET: DayOfWeek.Thursday.
    case thursday = 4

    /// Friday. .NET: DayOfWeek.Friday.
    case friday = 5

    /// Saturday. .NET: DayOfWeek.Saturday.
    case saturday = 6
}

/// Where the window stands in its lifecycle - the window's six EVENTS said as
/// STATE, so a view can ask "is anyone looking" without keeping a log of its
/// own. This library's own numbering: MAUI has the events and no such enum.
public enum WindowPhase: Int32, Sendable {
    /// The window is front and receiving input. After MAUI's Activated and
    /// nothing since.
    case activated = 0

    /// The window is visible and not the one being used. After Deactivated,
    /// and briefly after Resumed on the way back from `stopped`.
    case deactivated = 1

    /// The window is not visible at all - the app is backgrounded or hidden.
    /// After Stopped; MAUI's OnSleep moment.
    case stopped = 2
}

/// The battery, as the host last reported it. Resolve it with
/// `@Environment var battery: Battery`; the values update as the platform
/// reports, and exactly the views that read them are rebuilt.
///
/// What a DESKTOP answers is the platform's business and often nothing:
/// measured on Mac Catalyst, a machine on mains reports a charge of 0 and
/// never fires the change event - so read `chargeLevel <= 0` as "does not
/// say" rather than "empty". Android reports only when
/// `android.permission.BATTERY_STATS` is DECLARED in the manifest - never
/// requested at runtime, the declaration alone satisfies MAUI's check.
/// MAUI: Battery - Microsoft.Maui.Devices.
@StateClass
public final class Battery {
    /// How full the battery is, 0 to 1 - and -1 until the host has said,
    /// which a desktop may never do. MAUI: Battery.ChargeLevel.
    public var chargeLevel: Double = -1

    /// Charging, discharging, full. MAUI: Battery.State.
    public var state: BatteryState = .unknown

    /// Wall, USB, wireless, or the battery itself. MAUI: Battery.PowerSource.
    public var powerSource: BatteryPowerSource = .unknown

    /// Whether the platform's battery saver is on - a good reason to animate
    /// less. MAUI: Battery.EnergySaverStatus.
    public var energySaverStatus: EnergySaverStatus = .unknown

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. The values start as a headless host's do.
    public init() {}
}

/// The network, as the host last reported it. Resolve it with
/// `@Environment var connectivity: Connectivity`.
///
/// Android reports only with `android.permission.ACCESS_NETWORK_STATE`
/// declared in the manifest. A desktop wired to Ethernet may never fire a
/// change - measured on Mac Catalyst - so the VALUES are still right there;
/// it is the changes that are rare. MAUI: Connectivity -
/// Microsoft.Maui.Networking.
@StateClass
public final class Connectivity {
    /// Whether the internet is reachable - `.internet` is the one worth
    /// gating a request on. MAUI: Connectivity.NetworkAccess.
    public var networkAccess: NetworkAccess = .unknown

    /// Every way the device is connected right now - Wi-Fi and cellular at
    /// once is an ordinary answer on a phone. MAUI:
    /// Connectivity.ConnectionProfiles.
    public var connectionProfiles: [ConnectionProfile] = []

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. The values start as a headless host's do.
    public init() {}
}

/// The screen the interface is on, as the host last reported it. Resolve it
/// with `@Environment var display: DeviceDisplay`. Rotating a phone updates
/// `orientation`, `rotation`, `width` and `height` in one push. MAUI:
/// DeviceDisplay.MainDisplayInfo - Microsoft.Maui.Devices.
@StateClass
public final class DeviceDisplay {
    /// The screen's width in PIXELS - divide by `density` for the points a
    /// layout speaks. MAUI: DisplayInfo.Width.
    public var width: Double = 0

    /// The screen's height in pixels. MAUI: DisplayInfo.Height.
    public var height: Double = 0

    /// Pixels per layout point - 3 on a modern phone, 2 on a Mac. MAUI:
    /// DisplayInfo.Density.
    public var density: Double = 0

    /// Portrait or landscape. MAUI: DisplayInfo.Orientation.
    public var orientation: DisplayOrientation = .unknown

    /// How far the screen is rotated from its natural position. MAUI:
    /// DisplayInfo.Rotation.
    public var rotation: DisplayRotation = .unknown

    /// Frames per second the display draws, where the platform says - 0 where
    /// it does not. MAUI: DisplayInfo.RefreshRate.
    public var refreshRate: Double = 0

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. The values start as a headless host's do.
    public init() {}
}

/// The reader's language, region, zone and calendar habits, as the host
/// reports them. Resolve it with `@Environment var locale: LocaleInfo`.
///
/// The only provider here that is not named after a MAUI class, because .NET
/// spreads these over three - CultureInfo, RegionInfo and TimeZoneInfo - and
/// what an interface wants is one object. Its property names are therefore its
/// own, and each `///` says which .NET member answers it.
///
/// This is also where an application asks instead of asking Foundation, which
/// answers wrongly off Apple: `Locale.current` is a fallback `en_001` on
/// Android, and a Windows app links only `FoundationEssentials`, which has no
/// zone database at all. The HOST knows, and this is where it says.
@StateClass
public final class LocaleInfo {
    /// The two-letter language - "en", "pl". .NET:
    /// CultureInfo.TwoLetterISOLanguageName.
    public var language = ""

    /// The two-letter region - "US", "PL" - and empty where the culture has
    /// none. .NET: RegionInfo.TwoLetterISORegionName.
    public var region = ""

    /// The culture's full name - "en-PL". .NET: CultureInfo.Name.
    public var name = ""

    /// The current zone's IANA identifier - "Europe/Warsaw" - whatever the
    /// platform calls its zones; Windows names are converted, the
    /// `TimeZoneInfo.local()` act's rule. Empty until the host has said.
    public var timeZone = ""

    /// Whether times are written 14:30 rather than 2:30 PM. Read from the
    /// culture's short time pattern.
    public var uses24HourClock = false

    /// Which day a week starts on here. .NET:
    /// DateTimeFormatInfo.FirstDayOfWeek.
    public var firstDayOfWeek: Weekday = .sunday

    /// Metric or not. .NET: RegionInfo.IsMetric.
    public var isMetric = true

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. The values start as a headless host's do.
    public init() {}
}

/// The application, as the host describes it - the manifest facts, and the
/// one value here that CHANGES: the theme. Resolve it with
/// `@Environment var app: AppInfo`. MAUI: AppInfo -
/// Microsoft.Maui.ApplicationModel.
@StateClass
public final class AppInfo {
    /// The application's display name. MAUI: AppInfo.Name.
    public var name = ""

    /// The bundle or package identifier - "com.example.gallery".
    /// MAUI: AppInfo.PackageName.
    public var packageName = ""

    /// The version people read - "1.0". MAUI: AppInfo.VersionString.
    public var versionString = ""

    /// The build number behind it. MAUI: AppInfo.BuildString.
    public var buildString = ""

    /// Light or dark, as the system asks - updated live when the reader
    /// switches, so a view reading it follows the theme. Colours should not
    /// need it: `Color(light:dark:)` reads this very property as it is written
    /// onto a node, so a view that uses one already follows. This is for LOGIC
    /// that branches on the theme. MAUI: AppInfo.RequestedTheme.
    public var requestedTheme: AppTheme = .unspecified

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. The values start as a headless host's do.
    public init() {}
}

/// The kind of machine the interface is showing on, as the host reports it
/// before the first render - so the first tree already knows. Resolve it with
/// `@Environment var device: DeviceInfo`:
///
///     @Environment var device: DeviceInfo
///
///     var content: Element {
///         device.idiom == .desktop ? wideLayout : phoneLayout
///     }
///
/// The idiom is what separates a phone from a desktop where the PLATFORM
/// cannot: iOS is a phone and a tablet, and `stateUIPlatform()` - compiled
/// in - can never tell the two apart. Headless everything answers its
/// default, `.unknown` included, which the gallery reads as "show
/// everything". MAUI: DeviceInfo - Microsoft.Maui.Devices.
@StateClass
public final class DeviceInfo {
    /// Phone, tablet or desktop. MAUI: DeviceInfo.Idiom.
    public var idiom: DeviceIdiom = .unknown

    /// The platform's name as MAUI spells it - "iOS", "Android", "WinUI",
    /// "MacCatalyst". MAUI: DeviceInfo.Platform.
    ///
    /// TEXT rather than a numbered vocabulary, alone among the things the
    /// environment reports. MAUI's `DevicePlatform` is a struct with a
    /// `Create(String)` on it, so the set is open - a host may name a platform
    /// this library has never heard of - and an open vocabulary rides its
    /// spelling on a channel that has no dictionary to number it against.
    public var platform = ""

    /// The hardware model - "iPhone11,2", "CPH2363". MAUI: DeviceInfo.Model.
    public var model = ""

    /// Who made it - "Apple", "OnePlus". MAUI: DeviceInfo.Manufacturer.
    public var manufacturer = ""

    /// The device's own name, where the platform shares it. MAUI:
    /// DeviceInfo.Name.
    public var name = ""

    /// The operating system version - "17.5". MAUI: DeviceInfo.VersionString -
    /// MAUI's own `Version` is a `System.Version`, and what crosses here is the
    /// string, so this is the name that says which of the two it is.
    public var versionString = ""

    /// Real hardware or an emulator. MAUI: DeviceInfo.DeviceType.
    public var deviceType: DeviceType = .unknown

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. The values start as a headless host's do.
    public init() {}
}

/// The APPLICATION's place in its lifecycle, as STATE - resolve it with
/// `@Environment var window: WindowInfo` and read `window.phase`, instead of
/// keeping a flag the six Window lifecycle handlers would have to maintain.
///
/// **ONE OF THESE EXISTS, and it is the phase the LAST window to report
/// moved.** With one window on screen that is that window's; with several it
/// is the application's, which is the same thing MAUI's own
/// `Application.OnStart`, `OnSleep` and `OnResume` are - the host has no
/// per-window lifecycle to offer above the windows themselves. A view that
/// needs ONE window's phase takes it from that window, whose six handlers -
/// `onActivated`, `onDeactivated`, `onStopped`, `onResumed`, `onCreated`,
/// `onDestroying` - are each about the window they are written on:
///
///     struct InspectorWindow: Window {
///         @State private var awake = true
///
///         var onActivated: EventHandler? { { awake = true } }
///         var onDeactivated: EventHandler? { { awake = false } }
///
///         var content: Page { InspectorPage(awake: $awake) }
///     }
///
/// That is the same answer `onDestroying` gets, and for the same reason: what
/// belongs to one window of several is the author's to hold, there being no
/// binding for the library to write back through.
///
/// WHEN the phase moves is the platform's: a CPH2363 says deactivated then
/// stopped on every trip through the home screen, while Mac Catalyst raises
/// NOTHING on a mere focus switch and moves only around hiding and showing
/// the app - measured, both. The events themselves stay on the Window
/// modifiers; this is for a view that only wants to know where things stand.
@StateClass
public final class WindowInfo {
    /// Where the window stands right now. Starts `.activated`: a window
    /// being described is one being brought up.
    public var phase: WindowPhase = .activated

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. The values start as a live window's do.
    public init() {}
}

/// The channel's domains - which provider a `stateui_set_environment`
/// buffer is about. One byte on the wire; the C# writer spells the same
/// numbers.
enum EnvironmentDomain: UInt8 {
    /// The battery provider's values.
    case battery = 1

    /// The connectivity provider's values.
    case connectivity = 2

    /// The display provider's values.
    case display = 3

    /// The locale provider's values.
    case locale = 4

    /// The device provider's values.
    case device = 5

    /// The app provider's values.
    case app = 6

    /// The window-phase provider's value.
    case window = 7
}

/// The one instance of each standard provider, the scope they are seeded
/// into, and the applier the export hands a decoded buffer to.
///
/// The instances are internal ON PURPOSE: the way to read one is
/// `@Environment`, and a second public door would be a second way to do one
/// thing. They are seeded at the BOTTOM of every walk's scope, so an app
/// providing a fake with `.environment()` is nearer by construction and wins.
enum StandardEnvironment {
    // nonisolated(unsafe) for the reason every provider write and read is
    // safe: values are written by the host's pushes and read by builds, both
    // on the thread MAUI draws on.
    nonisolated(unsafe) static let battery = Battery()
    nonisolated(unsafe) static let connectivity = Connectivity()
    nonisolated(unsafe) static let display = DeviceDisplay()
    nonisolated(unsafe) static let locale = LocaleInfo()
    nonisolated(unsafe) static let device = DeviceInfo()
    nonisolated(unsafe) static let app = AppInfo()
    nonisolated(unsafe) static let window = WindowInfo()

    /// What every walk starts its scope with - one entry per provider, keyed
    /// exactly as `.environment()` keys what it stores.
    nonisolated(unsafe) static let scope: [(key: ObjectIdentifier, object: AnyObject)] = [
        (key: ObjectIdentifier(Battery.self), object: battery),
        (key: ObjectIdentifier(Connectivity.self), object: connectivity),
        (key: ObjectIdentifier(DeviceDisplay.self), object: display),
        (key: ObjectIdentifier(LocaleInfo.self), object: locale),
        (key: ObjectIdentifier(DeviceInfo.self), object: device),
        (key: ObjectIdentifier(AppInfo.self), object: app),
        (key: ObjectIdentifier(WindowInfo.self), object: window),
    ]

    /// The standard provider behind a type identity, if there is one - what
    /// an UNFILLED `@Environment` slot answers, which is how the application
    /// itself, built outside any walk, resolves the standard environment.
    static func object(for key: ObjectIdentifier) -> AnyObject? {
        scope.last(where: { $0.key == key })?.object
    }

    /// Applies one decoded push from the host. False for a domain this
    /// library does not know or a payload of the wrong shape - refused WHOLE,
    /// nothing half-applied, the family rule - which the host reports once as
    /// version skew.
    ///
    /// An enum value this library has no case for degrades to `.unknown`
    /// instead: a newer MAUI adding a battery state must not cost the whole
    /// battery its report.
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
        case .window:
            return applyWindow(values)
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
        // The profiles are a LIST OF MEMBERS, so `.values` of `.enumeration`
        // and not `.numbers`: a run of doubles is a run of quantities, and a
        // member is not one.
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
              let idiom = values[0].enumeration,
              let platform = values[1].string,
              let model = values[2].string,
              let manufacturer = values[3].string,
              let name = values[4].string,
              let versionString = values[5].string,
              let type = values[6].enumeration
        else { return false }

        device.idiom = DeviceIdiom(rawValue: idiom) ?? .unknown
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
        app.requestedTheme = AppTheme(rawValue: theme) ?? .unspecified
        return true
    }

    private static func applyWindow(_ values: [PropValue]) -> Bool {
        guard values.count == 1,
              let phase = values[0].enumeration.flatMap(WindowPhase.init(rawValue:))
        else { return false }

        window.phase = phase
        return true
    }
}
