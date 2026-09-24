// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The STANDARD ENVIRONMENT: the host's providers, seeded into every walk's
// scope and written through `StateUIHost`'s setters.
//
// The mechanism is the providers, StandardEnvironment.swift, the seeding in
// Differ.swift and `Node.built`, and the setters in StateUIHost.swift. The
// promises pinned here:
//
//   - a view resolves a standard provider with NOTHING provided anywhere;
//   - a host's report rebuilds exactly the views that read the changed
//     provider;
//   - an app's own `.environment(fake)` is nearer and wins;
//   - the APPLICATION's slots are filled from the same scope;
//   - every report lands whole, each field on the provider's property.

import XCTest
@_spi(Host) @testable import StateUI

/// Reads the battery - the view a report should rebuild.
private struct BatteryLabel: ContentView {
    @Environment var battery: Battery

    var content: any View {
        ModifiedContent(node: label("\(Int(battery.chargeLevel * 100))% \(battery.state)"))
    }
}

/// Reads the display through a COMPUTED PROPERTY used as a MODIFIER'S
/// ARGUMENT, inside a container's builder - which is the shape a page's own
/// heading is written in, and a different one from reading a provider
/// straight into a label.
private struct Heading: ContentView {
    @Environment var display: DeviceDisplay

    /// Whether the heading fits - the question a page asks of the screen.
    var fits: Bool { display.orientation != .landscape }

    var content: any View {
        ModifiedContent(node: label(fits ? "fits" : "too wide"))
    }
}

/// Reads nothing of the environment - the view a report must leave alone.
private struct Bystander: ContentView {
    let builds: Builds

    var content: any View {
        builds.count += 1
        return ModifiedContent(node: label("still"))
    }
}

/// Counts how often a body ran - a class, so the Mirror walk leaves it alone.
private final class Builds {
    var count = 0
}

/// The shape of an application: not a view, built outside any walk, so
/// nothing ever fills its slots - the unfilled-slot fallback is what answers.
private struct AppShaped {
    @Environment var device: DeviceInfo
    @Environment var application: ApplicationSession
}

final class HostEnvironmentTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
    }

    override func tearDown() {
        // The providers are process-wide on purpose, so every mutation here
        // is put back - a later test reading the headless defaults must find
        // them.
        StandardEnvironment.battery.chargeLevel = -1
        StandardEnvironment.battery.state = .unknown
        StandardEnvironment.battery.powerSource = .unknown
        StandardEnvironment.battery.energySaverStatus = .unknown
        StandardEnvironment.connectivity.networkAccess = .unknown
        StandardEnvironment.connectivity.connectionProfiles = []
        StandardEnvironment.device.formFactor = .unknown
        StandardEnvironment.device.platform = ""
        StandardEnvironment.device.model = ""
        StandardEnvironment.device.manufacturer = ""
        StandardEnvironment.device.name = ""
        StandardEnvironment.device.versionString = ""
        StandardEnvironment.device.deviceType = .unknown
        StandardEnvironment.app.name = ""
        StandardEnvironment.app.packageName = ""
        StandardEnvironment.app.versionString = ""
        StandardEnvironment.app.buildString = ""
        StandardEnvironment.app.requestedTheme = .system
        StandardEnvironment.application.phase = .active

        // Display providers are process-wide. Restore every field so a later
        // test starts from the headless environment rather than this test's
        // screen.
        StandardEnvironment.display.width = 0
        StandardEnvironment.display.height = 0
        StandardEnvironment.display.density = 0
        StandardEnvironment.display.orientation = .unknown
        StandardEnvironment.display.rotation = .unknown
        StandardEnvironment.display.refreshRate = 0
        StandardEnvironment.locale.language = ""
        StandardEnvironment.locale.region = ""
        StandardEnvironment.locale.name = ""
        StandardEnvironment.locale.timeZone = ""
        StandardEnvironment.locale.uses24HourClock = false
        StandardEnvironment.locale.firstDayOfWeek = .sunday
        StandardEnvironment.locale.isMetric = true
        StandardEnvironment.locale.layoutDirection = .leftToRight
        Renderer.shared.clearInvalidation()
        super.tearDown()
    }

    private var changed: Set<ObjectIdentifier> { Renderer.shared.pendingChanges }

    // MARK: - Resolution

    func testAStandardProviderResolvesWithNothingProvided() {
        let renders = Renders()

        let patch = renders.render(stack([BatteryLabel().body], id: "root"))

        XCTAssertEqual(
            patch.child(.auto(1))?.props["text"], .string("-100% unknown"),
            "the headless defaults - nothing was provided anywhere")
    }

    func testAHostReportRebuildsExactlyTheReader() {
        let renders = Renders()
        let builds = Builds()

        renders.render(stack([
            BatteryLabel().body,
            Bystander(builds: builds).body,
        ], id: "root"))
        XCTAssertEqual(builds.count, 1)

        StateUIHost.setBatteryInfo(HostBatteryInfo(
            chargeLevel: 0.87, state: .charging, powerSource: .ac, energySaverStatus: .on))

        let patch = renders.revisit(changed: changed)

        XCTAssertEqual(
            patch.child(.auto(1))?.props["text"], .string("87% charging"))
        XCTAssertEqual(builds.count, 1, "a view that reads no battery is left alone")
    }

    /// A report that says again what the host said changes no state and asks for no render: a platform
    /// that reports on every tick of its battery or its network costs nothing between real changes.
    func testAReportThatChangesNothingAsksForNoRender() {
        let renders = Renders()
        renders.render(stack([BatteryLabel().body], id: "root"))
        let battery = HostBatteryInfo(chargeLevel: 0.5, state: .charging, powerSource: .usb, energySaverStatus: .off)
        let network = HostConnectivityInfo(networkAccess: .internet, connectionProfiles: [.wiFi])
        let locale = HostLocaleInfo(
            language: "ar", region: "EG", name: "ar-EG", timeZone: "Africa/Cairo", uses24HourClock: false,
            firstDayOfWeek: .saturday, isMetric: true, layoutDirection: .rightToLeft)
        StateUIHost.setBatteryInfo(battery)
        StateUIHost.setConnectivityInfo(network)
        StateUIHost.setLocaleInfo(locale)
        renders.revisit(changed: changed)
        Renderer.shared.clearInvalidation()

        StateUIHost.setBatteryInfo(battery)
        StateUIHost.setConnectivityInfo(network)
        StateUIHost.setLocaleInfo(locale)

        XCTAssertTrue(changed.isEmpty, "\(changed.count) states written with what they held")
        XCTAssertFalse(StateUIHost.needsRender)
    }

    /// A page decides whether its heading fits from the screen's orientation,
    /// and a turn of the device has to reach it - through a computed property
    /// read as a modifier's argument, which is where a page asks.
    func testAReportReachesAReaderBehindAComputedProperty() {
        let renders = Renders()

        let first = renders.render(stack([Heading().body], id: "root"))

        XCTAssertEqual(
            first.child(.auto(1))?.props["text"], .string("fits"),
            "the headless default is not landscape")

        StateUIHost.setDisplayInfo(HostDisplayInfo(
            width: 2400, height: 1080, density: 3,
            orientation: .landscape, rotation: .rotation90, refreshRate: 60))

        XCTAssertEqual(
            StandardEnvironment.display.orientation, .landscape,
            "the provider took the report")

        let patch = renders.revisit(changed: changed)

        XCTAssertEqual(
            patch.child(.auto(1))?.props["text"], .string("too wide"),
            "the heading learned it no longer fits")
    }

    func testAFakeProvidedNearerWins() {
        let renders = Renders()
        let fake = Battery()
        fake.chargeLevel = 0.07
        fake.state = .discharging

        Renderer.shared.clearInvalidation()
        let patch = renders.render(
            stack([BatteryLabel().environment(fake).body], id: "root"))

        XCTAssertEqual(
            patch.child(.auto(1))?.props["text"], .string("7% discharging"),
            "an app's own .environment() is nearer than the seed and wins")
    }

    func testTheStructuralBuiltResolvesTheStandardProviders() {
        let tree = stack([BatteryLabel().body], id: "root").built

        XCTAssertEqual(tree.children[0].props[.text], .string("-100% unknown"))
    }

    func testAnUnfilledSlotOfAStandardTypeAnswersTheProvider() {
        let app = AppShaped()

        XCTAssertTrue(app.device === StandardEnvironment.device,
                      "the application resolves the very objects the views do")
        XCTAssertTrue(app.application === StandardEnvironment.application)
    }

    // MARK: - The phase

    func testTheApplicationPhaseFollowsTheHost() {
        XCTAssertEqual(StandardEnvironment.application.phase, .active)

        StateUIHost.setApplicationPhase(.background)
        XCTAssertEqual(StandardEnvironment.application.phase, .background)

        StateUIHost.setApplicationPhase(.inactive)
        XCTAssertEqual(StandardEnvironment.application.phase, .inactive)
    }

    // MARK: - The provider schema

    /// Every report lands whole: each field on the provider's property of the
    /// same name. Naming every public provider property here makes a rename or
    /// a shape change an explicit contract change instead of following one
    /// platform API.
    func testEveryReportLandsOnItsProvidersProperties() {
        StateUIHost.setBatteryInfo(HostBatteryInfo(
            chargeLevel: 0.42, state: .discharging, powerSource: .battery, energySaverStatus: .off))
        XCTAssertEqual(StandardEnvironment.battery.chargeLevel, 0.42)
        XCTAssertEqual(StandardEnvironment.battery.state, .discharging)
        XCTAssertEqual(StandardEnvironment.battery.powerSource, .battery)
        XCTAssertEqual(StandardEnvironment.battery.energySaverStatus, .off)

        StateUIHost.setConnectivityInfo(HostConnectivityInfo(
            networkAccess: .constrainedInternet, connectionProfiles: [.wiFi, .ethernet]))
        XCTAssertEqual(StandardEnvironment.connectivity.networkAccess, .constrainedInternet)
        XCTAssertEqual(StandardEnvironment.connectivity.connectionProfiles, [.wiFi, .ethernet])

        StateUIHost.setDisplayInfo(HostDisplayInfo(
            width: 2_400, height: 1_080, density: 2,
            orientation: .landscape, rotation: .rotation180, refreshRate: 120))
        XCTAssertEqual(StandardEnvironment.display.width, 2_400)
        XCTAssertEqual(StandardEnvironment.display.height, 1_080)
        XCTAssertEqual(StandardEnvironment.display.density, 2)
        XCTAssertEqual(StandardEnvironment.display.orientation, .landscape)
        XCTAssertEqual(StandardEnvironment.display.rotation, .rotation180)
        XCTAssertEqual(StandardEnvironment.display.refreshRate, 120)

        StateUIHost.setLocaleInfo(HostLocaleInfo(
            language: "pl", region: "PL", name: "pl-PL", timeZone: "Europe/Warsaw",
            uses24HourClock: true, firstDayOfWeek: .monday, isMetric: true, layoutDirection: .rightToLeft))
        XCTAssertEqual(StandardEnvironment.locale.language, "pl")
        XCTAssertEqual(StandardEnvironment.locale.region, "PL")
        XCTAssertEqual(StandardEnvironment.locale.name, "pl-PL")
        XCTAssertEqual(StandardEnvironment.locale.timeZone, "Europe/Warsaw")
        XCTAssertTrue(StandardEnvironment.locale.uses24HourClock)
        XCTAssertEqual(StandardEnvironment.locale.firstDayOfWeek, .monday)
        XCTAssertTrue(StandardEnvironment.locale.isMetric)
        XCTAssertEqual(StandardEnvironment.locale.layoutDirection, .rightToLeft)

        StateUIHost.setDeviceInfo(HostDeviceInfo(
            formFactor: .desktop, platform: "macOS", model: "Mac14,9", manufacturer: "Apple",
            name: "Studio", versionString: "26.0", deviceType: .physical))
        XCTAssertEqual(StandardEnvironment.device.formFactor, .desktop)
        XCTAssertEqual(StandardEnvironment.device.platform, "macOS")
        XCTAssertEqual(StandardEnvironment.device.model, "Mac14,9")
        XCTAssertEqual(StandardEnvironment.device.manufacturer, "Apple")
        XCTAssertEqual(StandardEnvironment.device.name, "Studio")
        XCTAssertEqual(StandardEnvironment.device.versionString, "26.0")
        XCTAssertEqual(StandardEnvironment.device.deviceType, .physical)

        StateUIHost.setApplicationInfo(HostApplicationInfo(
            name: "Gallery", packageName: "com.example.gallery", versionString: "1.2", buildString: "34"))
        StateUIHost.setTheme(.dark)
        XCTAssertEqual(StandardEnvironment.app.name, "Gallery")
        XCTAssertEqual(StandardEnvironment.app.packageName, "com.example.gallery")
        XCTAssertEqual(StandardEnvironment.app.versionString, "1.2")
        XCTAssertEqual(StandardEnvironment.app.buildString, "34")
        XCTAssertEqual(StandardEnvironment.app.requestedTheme, .dark)

        StateUIHost.setApplicationPhase(.inactive)
        XCTAssertEqual(StandardEnvironment.application.phase, .inactive)
    }
}
