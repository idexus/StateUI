// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The STANDARD ENVIRONMENT: what the host knows, provided to every tree.
//
// The battery, the network, the display, the locale, the device, the app and
// the application's phase are all state the HOST holds and this side can only
// be told about. Each is a class of `@State` properties the differ seeds into the scope
// of every walk, so any view resolves it the way it resolves an object an
// ancestor provided:
//
//     struct SaveButton: ContentView {
//         @Environment var connectivity: Connectivity
//
//         var content: any View {
//             Button("Save").isEnabled(connectivity.networkAccess == .internet)
//         }
//     }
//
// Nothing is registered and nothing is passed down - the type is the key, the
// standard rule. The objects live for the process. A same-process host writes
// them through `StateUIHost`; a foreign host uses the versioned
// `stateui_set_environment` boundary. The host seeds them before the first
// render and updates them whenever the platform reports a change. A write
// lands on the property's own `@State`, so
// exactly the views that READ the changed PROPERTY are rebuilt - a battery
// level moving reaches the views showing the level and not the ones gating on
// the saver - and a view that reads none of this costs nothing.
//
// A test - or an app that wants to lie to one branch - provides a fake with
// the ordinary modifier, and the nearer object wins:
//
//     let fake = Battery()
//     fake.chargeLevel = 0.07
//     ChildView().environment(fake)
//
// THE NUMBERS THESE ENUMS CARRY ARE STATEUI'S. Each closed vocabulary uses an
// explicit Int32 number and crosses a foreign-host boundary as `.enumeration`.
// A host translates its native value onto this vocabulary; native enum numbers
// never become part of StateUI's contract.

/// How the battery is doing.
public enum BatteryState: Int32, Sendable {
    /// The host has not said.
    case unknown = 0

    /// Plugged in and charging.
    case charging = 1

    /// Running on the battery.
    case discharging = 2

    /// Plugged in and full.
    case full = 3

    /// Plugged in and not charging, such as while held at a charge limit.
    case notCharging = 4

    /// There is no battery in this machine.
    case notPresent = 5
}

/// Where the power is coming from.
public enum BatteryPowerSource: Int32, Sendable {
    /// The host has not said.
    case unknown = 0

    /// The battery itself.
    case battery = 1

    /// A charger in the wall.
    case ac = 2

    /// A USB port.
    case usb = 3

    /// A wireless pad.
    case wireless = 4
}

/// Whether the platform's battery saver is on.
public enum EnergySaverStatus: Int32, Sendable {
    /// The host has not said.
    case unknown = 0

    /// The saver is on, so the application can reduce optional work.
    case on = 1

    /// The saver is off.
    case off = 2
}

/// What the network can reach.
public enum NetworkAccess: Int32, Sendable {
    /// The host has not said.
    case unknown = 0

    /// No network at all.
    case none = 1

    /// The local network only, with no route out.
    case local = 2

    /// The internet is reachable through a portal or another constraint.
    case constrainedInternet = 3

    /// The internet is reachable.
    case internet = 4
}

/// One way the device is connected.
public enum ConnectionProfile: Int32, Sendable {
    /// A kind this library has no name for.
    case unknown = 0

    /// Bluetooth.
    case bluetooth = 1

    /// A mobile data connection.
    case cellular = 2

    /// A wired network.
    case ethernet = 3

    /// Wi-Fi.
    case wiFi = 4
}

/// Which way the screen is turned, coarsely.
public enum DisplayOrientation: Int32, Sendable {
    /// The host has not said.
    case unknown = 0

    /// Taller than wide.
    case portrait = 1

    /// Wider than tall.
    case landscape = 2
}

/// How far the screen is rotated from its natural position.
public enum DisplayRotation: Int32, Sendable {
    /// The host has not said.
    case unknown = 0

    /// Not rotated.
    case rotation0 = 1

    /// A quarter turn.
    case rotation90 = 2

    /// Upside down.
    case rotation180 = 3

    /// Three quarters.
    case rotation270 = 4
}

/// Which look the system asked for.
public enum Theme: Int32, Sendable {
    /// The system did not say.
    case system = 0

    /// Light.
    case light = 1

    /// Dark.
    case dark = 2
}

/// Whether this is real hardware.
public enum DeviceType: Int32, Sendable {
    /// The host has not said.
    case unknown = 0

    /// A physical device.
    case physical = 1

    /// An emulator or a simulator.
    case virtual = 2
}

/// The first day of a calendar week reported by `LocaleInfo.firstDayOfWeek`.
public enum Weekday: Int32, Sendable {
    /// Sunday.
    case sunday = 0

    /// Monday.
    case monday = 1

    /// Tuesday.
    case tuesday = 2

    /// Wednesday.
    case wednesday = 3

    /// Thursday.
    case thursday = 4

    /// Friday.
    case friday = 5

    /// Saturday.
    case saturday = 6
}

/// Where a window stands in its life - six host events exposed as state, so a
/// view asks where things stand instead of keeping a second lifecycle log.
/// Every host maps its native window lifecycle onto the same deterministic
/// sequence.
public enum WindowPhase: Sendable {
    /// The platform has made the window, and nothing has happened to it
    /// since.
    case created

    /// The window is in front and receiving input.
    case activated

    /// The window is showing and is not the one in use - on its way to the
    /// background, or with another in front.
    case deactivated

    /// The window cannot be seen: it is minimized, hidden with its scene, or
    /// its application is hidden or in the background. The place to save -
    /// nothing promises the process comes back.
    case stopped

    /// The window has come back after `stopped`, on its way to `activated`.
    case resumed

    /// The window is going away - the last word before it has gone, whoever
    /// took it.
    case destroying
}

/// Where the application stands - in front, showing behind another
/// application, or out of sight. The host derives it from native application
/// and window events.
public enum ApplicationPhase: Int32, Sendable {
    /// One of its windows is the one in use.
    case active = 0

    /// Its windows are showing, and another application is in front.
    case inactive = 1

    /// None of its windows can be seen - it is hidden, or in the background.
    case background = 2
}

/// The battery, as the host last reported it. Resolve it with
/// `@Environment var battery: Battery`; the values update as the platform
/// reports, and exactly the views that read them are rebuilt.
///
/// A host that cannot observe a battery leaves `chargeLevel` at `-1` and the
/// remaining values at `.unknown`.
public final class Battery {
    /// How full the battery is, 0 to 1 - and -1 until the host has said,
    /// which a host without battery information may never do.
    @State public var chargeLevel: Double = -1

    /// Charging, discharging, full, or another settled battery state.
    @State public var state: BatteryState = .unknown

    /// Wall, USB, wireless, or the battery itself.
    @State public var powerSource: BatteryPowerSource = .unknown

    /// Whether the platform's battery saver is on - a good reason to animate
    /// less.
    @State public var energySaverStatus: EnergySaverStatus = .unknown

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. The values start as a headless host's do.
    public init() {}
}

/// The network, as the host last reported it. Resolve it with
/// `@Environment var connectivity: Connectivity`.
///
/// A host that cannot observe reachability reports `.unknown` and an empty
/// profile list.
public final class Connectivity {
    /// Whether the internet is reachable - `.internet` is the one worth
    /// gating a request on.
    @State public var networkAccess: NetworkAccess = .unknown

    /// Every way the device is connected right now - Wi-Fi and cellular at
    /// once is an ordinary answer on a phone.
    @State public var connectionProfiles: [ConnectionProfile] = []

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. The values start as a headless host's do.
    public init() {}
}

/// The screen the interface is on, as the host last reported it. Resolve it
/// with `@Environment var display: DeviceDisplay`. Rotating a phone updates
/// `orientation`, `rotation`, `width` and `height` in one host update.
public final class DeviceDisplay {
    /// The screen's width in PIXELS - divide by `density` for the points a
    /// layout speaks.
    @State public var width: Double = 0

    /// The screen's height in pixels.
    @State public var height: Double = 0

    /// Pixels per layout point - 3 on a modern phone, 2 on a Mac.
    @State public var density: Double = 0

    /// Portrait or landscape.
    @State public var orientation: DisplayOrientation = .unknown

    /// How far the screen is rotated from its natural position.
    @State public var rotation: DisplayRotation = .unknown

    /// Frames per second the display draws, where the platform says - 0 where
    /// it does not.
    @State public var refreshRate: Double = 0

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. The values start as a headless host's do.
    public init() {}
}

/// The reader's language, region, zone and calendar habits, as the host
/// reports them. Resolve it with `@Environment var locale: LocaleInfo`.
///
/// The host owns platform locale conversion. Application views consume one
/// stable StateUI vocabulary without importing a platform-specific locale API.
public final class LocaleInfo {
    /// The two-letter language, such as "en" or "pl".
    @State public var language = ""

    /// The two-letter region, such as "US" or "PL", and empty where the
    /// locale has none.
    @State public var region = ""

    /// The locale's full name, such as "en-PL".
    @State public var name = ""

    /// The current zone's IANA identifier, such as "Europe/Warsaw". The host
    /// normalizes its native identifier; empty means it has not said.
    @State public var timeZone = ""

    /// Whether the locale writes times as 14:30 rather than 2:30 PM.
    @State public var uses24HourClock = false

    /// Which day a week starts on here.
    @State public var firstDayOfWeek: Weekday = .sunday

    /// Whether the locale uses metric units.
    @State public var isMetric = true

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. The values start as a headless host's do.
    public init() {}
}

/// The application, as the host describes it - the manifest facts, and the
/// one value here that CHANGES: the theme. Resolve it with
/// `@Environment var app: AppInfo`.
public final class AppInfo {
    /// The application's display name.
    @State public var name = ""

    /// The bundle or package identifier, such as "com.example.gallery".
    @State public var packageName = ""

    /// The version people read, such as "1.0".
    @State public var versionString = ""

    /// The build number behind it.
    @State public var buildString = ""

    /// Light or dark, as the system asks - updated live when the reader
    /// switches, so a view reading it follows the theme. Colours should not
    /// need it: the differ reads this very property as it builds an element
    /// wearing a `Color(light:dark:)`, so that element already follows. This
    /// property is for logic that branches on the theme.
    @State public var requestedTheme: Theme = .system

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
///     var content: any View {
///         device.formFactor == .desktop ? wideLayout : phoneLayout
///     }
///
/// The formFactor distinguishes form factors that share an operating system. A
/// headless host leaves values at their documented defaults.
public final class DeviceInfo {
    /// Phone, tablet, desktop, television, or watch.
    @State public var formFactor: FormFactor = .unknown

    /// The host platform's name, such as "macOS", "iOS", "Android",
    /// "Windows", "Linux", or "Web". This is authored text because the set
    /// is open and a host may name a platform this release does not know.
    @State public var platform = ""

    /// The hardware model, where the platform shares it.
    @State public var model = ""

    /// Who made the device, where the platform shares it.
    @State public var manufacturer = ""

    /// The device's own name, where the platform shares it.
    @State public var name = ""

    /// The operating system version as displayable text.
    @State public var versionString = ""

    /// Real hardware or an emulator.
    @State public var deviceType: DeviceType = .unknown

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. The values start as a headless host's do.
    public init() {}
}

/// The application as it runs: where it stands, what its controls look like,
/// how its values move, what it keeps between launches, and opening another of
/// its scenes. This library's own.
///
///     @Environment private var application: ApplicationSession
///
///     Button("New window").onClicked { try await application.openScene() }
///
/// A SESSION is one opening of something declared: the application from its
/// start to the end of its process, a scene from its main window opening to
/// its closing, a window from `.created` to `.destroying`, a content page for
/// as long as its element lives. Each is in the environment of everything
/// under it - `ApplicationSession`, `SceneSession`, `WindowSession`,
/// `PageSession` - so a view acts on the one it is in, and says which by
/// the one it holds, from a handler, an engine or a task alike.
public final class ApplicationSession {
    /// Where the application stands: in front, behind another application, or
    /// out of sight, as the host maps its native application and window
    /// lifecycle.
    @State public internal(set) var phase: ApplicationPhase = .active

    /// The sessions of the scenes open right now, in the order they opened -
    /// read like any state, so a view that shows them is built again as a
    /// scene opens or closes.
    ///
    ///     Label("\(application.scenes.count) open")
    ///
    /// Made as it is read, from the application's own list of scenes: nothing
    /// here holds a scene, and each scene holds its own session.
    public var scenes: [SceneSession] { Scenes.shared.list.map(\.session) }

    /// The styles every control in the application can be given. A style sheet
    /// contains StateUI styles alone.
    ///
    ///     init() {
    ///         application.styles = StyleSheet {
    ///             Style<Label>().fontSize(14)
    ///         }
    ///     }
    ///
    /// Never sent: a style is resolved on this side, into the controls it
    /// applies to - and a colour in one is picked for the theme as each
    /// control is built, so a sheet written once serves both themes. Written
    /// again, it is the next render's sheet. See Views/Style.swift.
    @State public var styles: StyleSheet? = nil

    /// How every value in the application MOVES when it changes.
    /// This library's own.
    ///
    ///     application.motion = .spring(response: 260)
    ///
    /// A change TRAVELS to its new setting rather than appearing there - a
    /// colour crosses to the colour it became, a view that grew arrives at its
    /// size - and this is the one place that is said for a whole application.
    /// `.none` turns it off everywhere and leaves every value snapping, which
    /// is what an application says when it draws its own movement.
    ///
    /// A single view overrides it with `.motion(_:)`, a single value with
    /// `@State(motion:)`, a single write with `$state.journey.snap(to:)` or
    /// `$state.journey.move(to:_:)`. Never sent: what rides the wire is the
    /// law, as a transitions entry beside each moving property. See
    /// Types/Motion.swift.
    @State public var motion: Motion = .standard

    /// Every piece of state the application KEEPS between launches.
    ///
    ///     init() {
    ///         application.persistentKeys = [.lastGroup, .appearance]
    ///     }
    ///
    /// The host reads exactly these out of the store before the first view is
    /// built, so a `@State(persistentKey: .lastGroup)` already holds what the
    /// reader left behind the first time anything looks at it - which is why
    /// they are written where the application is MADE, in its `init`: the host
    /// asks for them as the application registers.
    ///
    /// **A key left off this list is never read.** State declared with it
    /// still SAVES - the write knows its own key - so the value appears on the
    /// launch after next and the symptom is a setting that lags one run
    /// behind. The list is the one thing that cannot be worked out from the
    /// views, because a store is read key by key and the views that would name
    /// the keys do not exist yet. See Core/Persistence.swift.
    @State public var persistentKeys: [PersistentKey] = []

    /// WHERE that state is kept - the platform preferences store unless the
    /// application says otherwise.
    ///
    /// The platform's own settings store unless the application names one it
    /// registered on the host side with `StateUIStores.Add` - which is what an
    /// application writes when its settings belong in a file of its own rather
    /// than beside the platform's. Written in `init` with the keys.
    @State public var persistentStorage: PersistentStorage = .preferences

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. It opens scenes as the application's own does.
    public init() {}

    /// Opens another session of the application: a new scene, its main window
    /// first - what *File ▸ New Window* does, asked from the interface.
    ///
    /// - Throws: `WindowError.unsupported` where the platform opens no second
    ///   window - a phone.
    public nonisolated(nonsending) func openScene() async throws {
        try Scenes.shared.openScene()
    }

    /// Forgets what an application wrote - what a registration starts from, so
    /// a second one inherits none of the first one's styles or keys.
    func forget() {
        styles = nil
        motion = .standard
        persistentKeys = []
        persistentStorage = .preferences
    }
}

/// Where a scene stands - in front, showing behind another, or out of sight.
/// This is StateUI's cross-platform ownership and lifecycle boundary.
public enum ScenePhase: Sendable {
    /// The scene is the one in front: one of its windows is the one in use.
    case active

    /// The scene is showing, and another is in front of it.
    case inactive

    /// The scene's main window is stopped, or the application is hidden or in
    /// the background. An owned window does not become a second scene
    /// lifecycle boundary.
    case background
}

/// A scene as it runs - one session of the application: where it stands, and
/// what is done to its windows. This library's own.
///
///     @Environment private var scene: SceneSession
///
///     Button("Fonts").onClicked { try await scene.openWindow(.fonts) }
///     Button("Document 7").onClicked { try await scene.openWindow(.document, value: 7) }
///     Label(scene.phase == .active ? "In front" : "Behind another window")
///
/// Every scene offers its own, so a view in one session acts on that session -
/// from a handler, an engine or a task alike, the session it holds saying
/// which. See `ApplicationSession` for what a session is.
public final class SceneSession {
    /// Where the scene stands right now. Starts `.active`: a scene being
    /// described is one being brought up.
    @State public internal(set) var phase: ScenePhase = .active

    /// The sessions of the scene's windows open right now: its main window's
    /// first, then the ones it opened beside it, in the order they opened -
    /// read like any state, so a view that shows them is built again as a
    /// window opens or closes. Nothing for a scene that has ended.
    ///
    ///     Label("\(scene.windows.count) windows")
    ///
    /// Made as it is read, from what the scene has open: nothing here holds a
    /// window, and a window's session knows its scene without keeping it.
    public var windows: [WindowSession] {
        guard let record = try? standing() else { return [] }

        return [record.windowSession(SceneElement.mainKey)]
            + record.windows.map { record.windowSession($0.key) }
    }

    /// The scene's number - what an inspector files the scene's renders
    /// under.
    let id: String

    /// The scene it is the session of - nothing for the one a view outside
    /// every scene reads, and nothing once that scene has ended.
    weak var record: SceneRecord?

    /// A scene's own, made by the scene it describes.
    init(id: String) {
        self.id = id
    }

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)` - one that is always in front and opens nothing.
    public convenience init() {
        self.init(id: "")
    }

    /// Opens the scene's window of a group that opens ONE.
    ///
    ///     Button("Fonts").onClicked { try await scene.openWindow(.fonts) }
    ///
    /// - Parameter type: the group's kind.
    /// - Throws: `WindowError.alreadyOpen` where it is open already, and the
    ///   rest of `WindowError` where the scene cannot open it.
    public nonisolated(nonsending) func openWindow(_ type: WindowType) async throws {
        try standing().open(type)
    }

    /// Opens the scene's window for a value.
    ///
    ///     Button("Open").onClicked { try await scene.openWindow(.document, value: id) }
    ///
    /// - Parameters:
    ///   - type: the group's kind.
    ///   - value: which value the window stands for.
    /// - Throws: `WindowError.alreadyOpen` where a window for that value is
    ///   open already, and the rest of `WindowError` where the scene cannot
    ///   open it.
    public nonisolated(nonsending) func openWindow<Value: Codable & Hashable>(
        _ type: WindowType,
        value: Value
    ) async throws {
        try standing().open(type, value: value)
    }

    /// Closes the scene's window of a group that opens ONE.
    ///
    /// - Parameter type: the group's kind.
    /// - Throws: `WindowError.notOpen` where it is not open, and
    ///   `WindowError.noScene` for a scene that has ended.
    public nonisolated(nonsending) func closeWindow(_ type: WindowType) async throws {
        try standing().close(type)
    }

    /// Closes the scene's window for a value.
    ///
    /// - Parameters:
    ///   - type: the group's kind.
    ///   - value: which value's window.
    /// - Throws: `WindowError.notOpen` where no window for that value is open,
    ///   and `WindowError.noScene` for a scene that has ended.
    public nonisolated(nonsending) func closeWindow<Value: Codable & Hashable>(
        _ type: WindowType,
        value: Value
    ) async throws {
        try standing().close(type, value: value)
    }

    /// Ends the session: its main window closes, and every window of it with
    /// it - what the reader closing the main window does.
    ///
    /// - Throws: `WindowError.noScene` for a scene that has ended already, and
    ///   `WindowError.unsupported` where the platform opens no second window, a
    ///   phone's one window being the application's.
    public nonisolated(nonsending) func close() async throws {
        try Scenes.shared.close(standing())
    }

    /// The scene, while it is open - asked of the application's list, so a
    /// session held after its scene ended answers that, whoever keeps the
    /// scene's record alive.
    private func standing() throws -> SceneRecord {
        guard let record, Scenes.shared.record(id: record.id) === record else {
            throw WindowError.noScene
        }

        return record
    }
}

/// A window as it runs: its lifecycle, title, requested geometry, chrome,
/// presented pages, and close operation.
///
///     @Environment private var window: WindowSession
///
///     VStack { … }
///         .onCreated {
///             window.title = "Gallery"
///             window.width = 1100
///             window.height = 800
///         }
///         .onChanged(window.phase) {
///             if window.phase == .stopped { try await save() }
///         }
///
///     Button("Close").onClicked { try await window.close() }
///
/// Every window offers its own, so a view acts on the window it is in, and
/// what the window is told stands until it is told otherwise. See
/// `ApplicationSession` for what a session is.
///
/// Geometry is a request to a host that exposes movable or resizable windows.
/// Each axis is independent: changing width does not restore an old height,
/// and changing x does not restore an old y. A `nil` axis stays under native
/// window management, including platform restoration and reader resizing.
/// Full-screen hosts may retain these values without presenting geometry.
public final class WindowSession {
    /// Where the window stands in its life right now. Starts `.created`.
    @State public internal(set) var phase: WindowPhase = .created

    /// What the window is called in native window chrome and system surfaces.
    @State public var title: String? = nil

    /// The horizontal position of the outer frame's top-left corner in the
    /// host's desktop coordinate space.
    @State public var x: Double? = nil

    /// The vertical position of the outer frame's top-left corner in the
    /// host's desktop coordinate space.
    @State public var y: Double? = nil

    /// The requested width of the window's content area.
    ///
    /// A size, not a fixed one: the user can still resize the window within
    /// whatever minimum and maximum it was given. For a size that cannot be
    /// changed, say so - a maximum equal to the minimum.
    @State public var width: Double? = nil

    /// The requested height of the window's content area.
    @State public var height: Double? = nil

    /// The minimum width of the window's content area.
    @State public var minimumWidth: Double? = nil

    /// The minimum height of the window's content area.
    @State public var minimumHeight: Double? = nil

    /// The maximum width of the window's content area.
    /// A smaller value than `minimumWidth` is treated as `minimumWidth`.
    @State public var maximumWidth: Double? = nil

    /// The maximum height of the window's content area.
    /// A smaller value than `minimumHeight` is treated as `minimumHeight`.
    @State public var maximumHeight: Double? = nil

    /// Whether the host permits the reader to maximize the window through any
    /// native affordance for that operation.
    @State public var isMaximizable: Bool? = nil

    /// Whether the host permits the reader to minimize the window through any
    /// native affordance for that operation.
    @State public var isMinimizable: Bool? = nil

    /// Authored window chrome presented by hosts that support a custom title
    /// area.
    ///
    ///     .onCreated {
    ///         if device.formFactor == .desktop {
    ///             window.titleBar = TitleBar("Notes").trailingContent { AccountButton() }
    ///         }
    ///     }
    ///
    /// The bar is what was written; a view in one of its slots is built where
    /// the bar is shown, so a composed view there reads its own state as it
    /// builds and is built again when that moves.
    @State public var titleBar: TitleBar? = nil

    /// The pages presented over the window, with the last page on top.
    ///
    ///     @State private var sheets: [Sheet] = []
    ///
    ///     .onCreated {
    ///         window.modalStack = ModalStack($sheets) { sheet in
    ///             switch sheet {
    ///             case .settings: SettingsPage(sheets: $sheets)
    ///             case .about: AboutPage()
    ///             }
    ///         }
    ///     }
    ///
    /// Written once: the stack reads the array as the window is built, so
    /// presenting a page is `sheets.append(.settings)`, dismissing one is a
    /// `remove`, and a sheet the reader drags away truncates the array itself.
    /// It belongs to the window rather than to any individual page. See
    /// `ModalStack`.
    @State public var modalStack: ModalStack? = nil

    /// The key the tree knows the window by in its scene.
    let key: String

    /// The scene the window is in - nothing for the one a view outside every
    /// window reads, and nothing once that scene has ended.
    weak var record: SceneRecord?

    /// A window's own, made by the scene it is in.
    init(key: String, record: SceneRecord?) {
        self.key = key
        self.record = record
    }

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)` - one that closes nothing.
    public convenience init() {
        self.init(key: "", record: nil)
    }

    /// Closes the window - and where it is its scene's main window, the scene
    /// with every window of it.
    ///
    /// - Throws: `WindowError.noScene` for a window of no open scene - one
    ///   whose scene has ended included, whoever still holds it -
    ///   `WindowError.notOpen` for one already closed, and
    ///   `WindowError.unsupported` where the host cannot close this window
    ///   independently.
    public nonisolated(nonsending) func close() async throws {
        guard let record, Scenes.shared.record(id: record.id) === record else {
            throw WindowError.noScene
        }

        if key == SceneElement.mainKey {
            try Scenes.shared.close(record)
        } else {
            try record.closeWindow(key: key)
        }
    }

    /// The explicitly authored window properties. An absent value leaves that
    /// capability under native window management.
    var props: [Prop: PropValue] {
        var props: [Prop: PropValue] = [:]

        props[.title] = title.map { .string($0) }
        props[.x] = x.map { .number($0) }
        props[.y] = y.map { .number($0) }
        props[.width] = width.map { .number($0) }
        props[.height] = height.map { .number($0) }
        props[.isMaximizable] = isMaximizable.map { .bool($0) }
        props[.isMinimizable] = isMinimizable.map { .bool($0) }
        props[.minimumWidth] = minimumWidth.map { .number($0) }
        props[.minimumHeight] = minimumHeight.map { .number($0) }
        props[.maximumWidth] = maximumWidth.map { .number($0) }
        props[.maximumHeight] = maximumHeight.map { .number($0) }

        return props
    }

    /// What hangs off the window besides its page: the chrome and the modal
    /// stack, each as the node the host knows it by - built as the window is,
    /// so the modal stack reads its array there.
    var slots: [Node] {
        var slots: [Node] = []

        if let bar = titleBar { slots.append(bar.body) }
        if let stack = modalStack { slots.append(stack.node) }

        return slots
    }
}

/// The channel's domains - which provider a `stateui_set_environment`
/// buffer is about. One byte on the wire; every foreign host spells the same
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

    /// The application's phase.
    case application = 7
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
    // safe: values are written by host pushes and read by builds, both on the
    // native host's UI thread.
    nonisolated(unsafe) static let battery = Battery()
    nonisolated(unsafe) static let connectivity = Connectivity()
    nonisolated(unsafe) static let display = DeviceDisplay()
    nonisolated(unsafe) static let locale = LocaleInfo()
    nonisolated(unsafe) static let device = DeviceInfo()
    nonisolated(unsafe) static let app = AppInfo()

    /// The application's session - one per process, its phase pushed by the
    /// host. See `ApplicationSession`.
    nonisolated(unsafe) static let application = ApplicationSession()

    /// What a view outside every scene reads as its scene - one that is always
    /// in front and opens nothing. Every scene offers its own, nearer. See
    /// Core/Scenes.swift.
    nonisolated(unsafe) static let scene = SceneSession()

    /// What a view outside every window reads as its window - one that closes
    /// nothing. Every window offers its own, nearer.
    nonisolated(unsafe) static let window = WindowSession()

    /// What a view outside every page reads as its page - one nothing shows.
    /// Every content page offers its own, nearer. See Types/PageSession.swift.
    nonisolated(unsafe) static let page = PageSession()

    /// What every walk starts its scope with - one entry per provider, keyed
    /// exactly as `.environment()` keys what it stores.
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
    /// instead: a newer host vocabulary must not cost the whole domain its
    /// report.
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
