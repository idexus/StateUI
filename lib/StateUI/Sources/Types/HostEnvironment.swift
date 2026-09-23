// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The standard environment: what the host knows - the battery, the network,
// the display, the locale, the device, the app and the application's phase -
// as objects of `@State` properties every view resolves with `@Environment`.
// Design: docs/design/types/environment.md#the-standard-environment

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

/// Where a window stands in its life, as state a view reads. Every host maps
/// its native window lifecycle onto the same sequence.
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
///     let fake = Battery()
///     fake.chargeLevel = 0.07
///     ChildView().environment(fake)
///
/// A host that cannot observe a battery leaves `chargeLevel` at `-1` and the
/// remaining values at `.unknown`. A test provides a fake, as above.
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

/// The user's language, region, zone and calendar habits, as the host
/// reports them. Resolve it with `@Environment var locale: LocaleInfo`.
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

    /// Light or dark, as the system asks, updated live when the user switches.
    /// A `Color(light:dark:)` follows the theme by itself; read this for logic
    /// that branches on the theme.
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
    /// "Windows", "Linux", or "Web" - text, since a host may name a platform
    /// this library does not know.
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
/// how its values animate, what it keeps between launches, and opening another
/// of its scenes.
///
///     @Environment private var application: ApplicationSession
///
///     Button("New window").onClicked { try await application.openScene() }
///
/// A session is one opening of something declared: the application from its
/// start to the end of its process, a scene from its main window opening to
/// its closing, a window from `.created` to `.destroying`, a content page for
/// as long as its element lives. Each is in the environment of everything
/// under it - `ApplicationSession`, `SceneSession`, `WindowSession`,
/// `PageSession` - so a view acts on the one it is in, from a handler, an
/// engine or a task alike.
///
/// Design: docs/design/types/sessions.md#one-opening-of-something-declared
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
    public var scenes: [SceneSession] { Scenes.shared.list.map(\.session) }

    /// The styles every control in the application can be given.
    ///
    ///     init() {
    ///         application.styles = StyleSheet {
    ///             Style<Label>().fontSize(14)
    ///         }
    ///     }
    ///
    /// A style resolves into the controls it applies to, and a colour pair in
    /// it follows the theme. A sheet written again is the next render's.
    @State public var styles: StyleSheet? = nil

    /// How every value in the application animates when it changes.
    ///
    ///     application.motion = .spring(response: 260)
    ///
    /// A colour animates to its new colour, a view that grew to its new size.
    /// `.none` turns animation off everywhere, for an application that draws
    /// its own. A view overrides it with `.motion(_:)`, a state with
    /// `@State(motion:)`, and one write with `$state.journey.snap(to:)` or
    /// `$state.journey.move(to:_:)`.
    @State public var motion: Motion = .standard

    /// Every key the application keeps between launches. Write it in the
    /// application's `init`: the host reads exactly these keys from the store
    /// before the first view is built.
    ///
    ///     init() {
    ///         application.persistentKeys = [.lastGroup, .appearance]
    ///     }
    ///
    /// **A key left off this list is never read.** State declared with it
    /// still saves, so its value arrives one launch late.
    ///
    /// Design: docs/design/types/sessions.md#kept-keys-are-declared
    @State public var persistentKeys: [PersistentKey] = []

    /// Where the kept state lives: the platform's preferences, or a store the
    /// application registered on the host side with `StateUIStores.Add`.
    /// Written in `init` with the keys.
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
public enum ScenePhase: Sendable {
    /// The scene is the one in front: one of its windows is the one in use.
    case active

    /// The scene is showing, and another is in front of it.
    case inactive

    /// The scene's main window is stopped, or the application is hidden or in
    /// the background. Only the main window decides: a window the scene
    /// opened beside it does not.
    case background
}

/// A scene as it runs - one session of the application: where it stands, and
/// what is done to its windows.
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
    /// it - what the user closing the main window does.
    ///
    /// - Throws: `WindowError.noScene` for a scene that has ended already, and
    ///   `WindowError.unsupported` where the platform opens no second window, a
    ///   phone's one window being the application's.
    public nonisolated(nonsending) func close() async throws {
        try Scenes.shared.close(standing())
    }

    /// The scene while the application still lists it; `WindowError.noScene`
    /// after it ended, whoever keeps its record alive.
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
/// window management, including platform restoration and the user's resizing.
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

    /// Whether the host permits the user to maximize the window through any
    /// native affordance for that operation.
    @State public var isMaximizable: Bool? = nil

    /// Whether the host permits the user to minimize the window through any
    /// native affordance for that operation.
    @State public var isMinimizable: Bool? = nil

    /// Whether the desktop shows through the window, blurred - under whatever
    /// its pages leave uncovered or paint in a colour that lets it through,
    /// such as a background with an alpha or the margin around a floating
    /// sidebar.
    ///
    ///     window.isTranslucent = true
    ///
    /// A desktop host lays its windows' own material under the pages; a host
    /// whose windows cannot show what is behind them keeps them opaque, and
    /// the application's colours read as they are written. `nil` keeps the
    /// platform's opaque window.
    @State public var isTranslucent: Bool? = nil

    /// Authored window chrome presented by hosts that support a custom title
    /// area.
    ///
    ///     .onCreated {
    ///         if device.formFactor == .desktop {
    ///             window.titleBar = TitleBar("Notes").trailingContent { AccountButton() }
    ///         }
    ///     }
    ///
    /// A view in one of the bar's slots is built where the bar is shown, and
    /// follows its own state.
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
    /// `remove`, and a sheet the user drags away truncates the array itself.
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

        props.describe(WindowContract.title, title)
        props.describe(WindowContract.x, x)
        props.describe(WindowContract.y, y)
        props.describe(WindowContract.width, width)
        props.describe(WindowContract.height, height)
        props.describe(WindowContract.isMaximizable, isMaximizable)
        props.describe(WindowContract.isMinimizable, isMinimizable)
        props.describe(WindowContract.isTranslucent, isTranslucent)
        props.describe(WindowContract.minimumWidth, minimumWidth)
        props.describe(WindowContract.minimumHeight, minimumHeight)
        props.describe(WindowContract.maximumWidth, maximumWidth)
        props.describe(WindowContract.maximumHeight, maximumHeight)

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

/// Which provider a `stateui_set_environment` buffer is about: one byte, the
/// same number in every host.
enum EnvironmentDomain: UInt8 {
    case battery = 1
    case connectivity = 2
    case display = 3
    case locale = 4
    case device = 5
    case app = 6

    /// The application's phase.
    case application = 7
}

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
