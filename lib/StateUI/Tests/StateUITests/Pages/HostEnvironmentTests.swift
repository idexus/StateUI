// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The STANDARD ENVIRONMENT: the host's providers, seeded into every walk's
// scope and written through `stateui_set_environment`.
//
// The mechanism is the providers and their applier, StandardEnvironment.swift,
// the seeding in Core/Diff.swift and `Node.built`, and the export in
// Bridge/Exports.swift. The promises pinned here:
//
//   - a view resolves a standard provider with NOTHING provided anywhere;
//   - a push through the real export rebuilds exactly the views that read
//     the changed provider;
//   - an app's own `.environment(fake)` is nearer and wins;
//   - the APPLICATION's slots are filled from the same scope;
//   - a push that will not read is refused whole - nothing half-applied;
//   - a member arrives as `.enumeration`, this library's own number for it,
//     and a member this side has no case for degrades rather than costing the
//     whole domain its report.

import XCTest
@_spi(Host) @testable import StateUI

/// Reads the battery - the view a push should rebuild.
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

/// Reads nothing of the environment - the view a push must leave alone.
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
        // test starts from the headless environment rather than this fixture's
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
        Renderer.shared.clearInvalidation()
        super.tearDown()
    }

    private var changed: Set<ObjectIdentifier> { Renderer.shared.pendingChanges }

    /// The export's bytes: version, domain, then the counted value list every
    /// host channel shares - built with the library's own append helpers.
    private func push(_ domain: UInt8, _ values: [PropValue]) -> Int32 {
        var out: [UInt8] = []
        out.u8(Wire.version)
        out.u8(domain)
        out.u8(UInt8(values.count))
        for value in values { out.value(value) }

        return out.withUnsafeBufferPointer {
            stateui_set_environment($0.baseAddress, Int32($0.count))
        }
    }

    // MARK: - Resolution

    func testAStandardProviderResolvesWithNothingProvided() {
        let renders = Renders()

        let patch = renders.render(stack([BatteryLabel().body], id: "root"))

        XCTAssertEqual(
            patch.child(.auto(1))?.props["text"], .string("-100% unknown"),
            "the headless defaults - nothing was provided anywhere")
    }

    func testAHostPushRebuildsExactlyTheReader() {
        let renders = Renders()
        let builds = Builds()

        renders.render(stack([
            BatteryLabel().body,
            Bystander(builds: builds).body,
        ], id: "root"))
        XCTAssertEqual(builds.count, 1)

        XCTAssertEqual(push(1, [
            .number(0.87),
            .enumeration(BatteryState.charging.rawValue),
            .enumeration(BatteryPowerSource.ac.rawValue),
            .enumeration(EnergySaverStatus.on.rawValue),
        ]), 1)

        let patch = renders.revisit(changed: changed)

        XCTAssertEqual(
            patch.child(.auto(1))?.props["text"], .string("87% charging"))
        XCTAssertEqual(builds.count, 1, "a view that reads no battery is left alone")
    }

    /// A page decides whether its heading fits from the screen's orientation,
    /// and a turn of the device has to reach it - through a computed property
    /// read as a modifier's argument, which is where a page asks.
    func testAPushReachesAReaderBehindAComputedProperty() {
        let renders = Renders()

        let first = renders.render(stack([Heading().body], id: "root"))

        XCTAssertEqual(
            first.child(.auto(1))?.props["text"], .string("fits"),
            "the headless default is not landscape")

        XCTAssertEqual(push(3, [
            .number(2400),
            .number(1080),
            .number(3),
            .enumeration(DisplayOrientation.landscape.rawValue),
            .enumeration(DisplayRotation.rotation90.rawValue),
            .number(60),
        ]), 1)

        XCTAssertEqual(
            StandardEnvironment.display.orientation, .landscape,
            "the provider took the push")

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

    // MARK: - The domains

    func testTheApplicationPhaseFollowsTheHost() {
        XCTAssertEqual(StandardEnvironment.application.phase, .active)

        XCTAssertEqual(push(7, [.enumeration(ApplicationPhase.background.rawValue)]), 1)
        XCTAssertEqual(StandardEnvironment.application.phase, .background)

        XCTAssertEqual(push(7, [.enumeration(ApplicationPhase.inactive.rawValue)]), 1)
        XCTAssertEqual(StandardEnvironment.application.phase, .inactive)
    }

    func testTheDevicePushCarriesTheIdiom() {
        // Platform is an open vocabulary, so it rides as authored text while
        // the device formFactor remains a closed StateUI enumeration.
        XCTAssertEqual(push(5, [
            .enumeration(FormFactor.desktop.rawValue), .string("macOS"),
            .string("Mac14,9"), .string("Apple"), .string("mac"), .string("14.5"),
            .enumeration(DeviceType.physical.rawValue),
        ]), 1)

        XCTAssertEqual(StandardEnvironment.device.formFactor, .desktop)
        XCTAssertEqual(StandardEnvironment.device.deviceType, .physical)

        // An formFactor this library has no case for degrades to .unknown - the
        // host is at most a release newer, and unknown shows everything.
        XCTAssertEqual(push(5, [
            .enumeration(99), .string(""), .string(""),
            .string(""), .string(""), .string(""),
            .enumeration(DeviceType.unknown.rawValue),
        ]), 1)
        XCTAssertEqual(StandardEnvironment.device.formFactor, .unknown)
    }

    // MARK: - Refusals

    func testARefusedPushMovesNothing() {
        // The wrong length: a battery push carries four values, not two.
        XCTAssertEqual(
            push(1, [.number(0.5), .enumeration(BatteryState.charging.rawValue)]), 0)
        XCTAssertEqual(StandardEnvironment.battery.chargeLevel, -1,
                       "a refused push is refused WHOLE")

        // The wrong KIND: four values, and the state a plain number where a
        // member is wanted - what a host that stopped translating would send.
        XCTAssertEqual(push(1, [
            .number(0.5),
            .number(Double(BatteryState.charging.rawValue)),
            .enumeration(BatteryPowerSource.ac.rawValue),
            .enumeration(EnergySaverStatus.on.rawValue),
        ]), 0)
        XCTAssertEqual(StandardEnvironment.battery.chargeLevel, -1)

        // A domain this library does not know.
        XCTAssertEqual(push(99, [.number(1)]), 0)

        // A truncated buffer, refused at every cut.
        var whole: [UInt8] = []
        whole.u8(Wire.version)
        whole.u8(1)
        whole.u8(4)
        for value in [
            PropValue.number(0.5),
            .enumeration(BatteryState.charging.rawValue),
            .enumeration(BatteryPowerSource.ac.rawValue),
            .enumeration(EnergySaverStatus.on.rawValue),
        ] {
            whole.value(value)
        }

        for cut in 0..<whole.count {
            let result = Array(whole.prefix(cut)).withUnsafeBufferPointer {
                stateui_set_environment($0.baseAddress, Int32($0.count))
            }
            XCTAssertEqual(result, -1, "a buffer cut to \(cut) bytes was not refused")
        }

        // Another version's bytes.
        var other = whole
        other[0] = 1
        XCTAssertEqual(other.withUnsafeBufferPointer {
            stateui_set_environment($0.baseAddress, Int32($0.count))
        }, -1)

        XCTAssertEqual(StandardEnvironment.battery.chargeLevel, -1)
    }

    // MARK: - The numbers on the wire

    /// The numbers are frozen: a case may be APPENDED to one of these, never
    /// inserted, because the number is the whole of what crosses.
    ///
    /// Spelled out rather than derived, which is the point: a case inserted
    /// in the middle would silently reinterpret a foreign host's existing
    /// bytes. This is the line that notices.
    func testTheEnumsKeepTheNumbersTheyDeclare() {
        XCTAssertEqual(BatteryState.charging.rawValue, 1)
        XCTAssertEqual(BatteryState.notPresent.rawValue, 5)
        XCTAssertEqual(BatteryPowerSource.wireless.rawValue, 4)
        XCTAssertEqual(EnergySaverStatus.on.rawValue, 1)
        XCTAssertEqual(NetworkAccess.internet.rawValue, 4)
        XCTAssertEqual(ConnectionProfile.wiFi.rawValue, 4)
        XCTAssertEqual(DisplayOrientation.landscape.rawValue, 2)
        XCTAssertEqual(DisplayRotation.rotation270.rawValue, 4)
        XCTAssertEqual(Theme.dark.rawValue, 2)
        XCTAssertEqual(DeviceType.virtual.rawValue, 2)
        XCTAssertEqual(Weekday.saturday.rawValue, 6)
        XCTAssertEqual(FormFactor.desktop.rawValue, 3)
        XCTAssertEqual(ApplicationPhase.background.rawValue, 2)
    }

    // MARK: - The provider schema

    /// Every host domain has one ordered StateUI schema. This test names every
    /// public provider property directly, so a rename or a shape change must be
    /// an explicit contract change instead of following one platform API.
    func testEveryEnvironmentDomainAppliesItsCompleteStateUISchema() {
        XCTAssertEqual(push(1, [
            .number(0.42),
            .enumeration(BatteryState.discharging.rawValue),
            .enumeration(BatteryPowerSource.battery.rawValue),
            .enumeration(EnergySaverStatus.off.rawValue),
        ]), 1)
        XCTAssertEqual(StandardEnvironment.battery.chargeLevel, 0.42)
        XCTAssertEqual(StandardEnvironment.battery.state, .discharging)
        XCTAssertEqual(StandardEnvironment.battery.powerSource, .battery)
        XCTAssertEqual(StandardEnvironment.battery.energySaverStatus, .off)

        XCTAssertEqual(push(2, [
            .enumeration(NetworkAccess.constrainedInternet.rawValue),
            .values([
                .enumeration(ConnectionProfile.wiFi.rawValue),
                .enumeration(ConnectionProfile.ethernet.rawValue),
            ]),
        ]), 1)
        XCTAssertEqual(StandardEnvironment.connectivity.networkAccess, .constrainedInternet)
        XCTAssertEqual(StandardEnvironment.connectivity.connectionProfiles, [.wiFi, .ethernet])

        XCTAssertEqual(push(3, [
            .number(2_400),
            .number(1_080),
            .number(2),
            .enumeration(DisplayOrientation.landscape.rawValue),
            .enumeration(DisplayRotation.rotation180.rawValue),
            .number(120),
        ]), 1)
        XCTAssertEqual(StandardEnvironment.display.width, 2_400)
        XCTAssertEqual(StandardEnvironment.display.height, 1_080)
        XCTAssertEqual(StandardEnvironment.display.density, 2)
        XCTAssertEqual(StandardEnvironment.display.orientation, .landscape)
        XCTAssertEqual(StandardEnvironment.display.rotation, .rotation180)
        XCTAssertEqual(StandardEnvironment.display.refreshRate, 120)

        XCTAssertEqual(push(4, [
            .string("pl"),
            .string("PL"),
            .string("pl-PL"),
            .string("Europe/Warsaw"),
            .bool(true),
            .enumeration(Weekday.monday.rawValue),
            .bool(true),
        ]), 1)
        XCTAssertEqual(StandardEnvironment.locale.language, "pl")
        XCTAssertEqual(StandardEnvironment.locale.region, "PL")
        XCTAssertEqual(StandardEnvironment.locale.name, "pl-PL")
        XCTAssertEqual(StandardEnvironment.locale.timeZone, "Europe/Warsaw")
        XCTAssertTrue(StandardEnvironment.locale.uses24HourClock)
        XCTAssertEqual(StandardEnvironment.locale.firstDayOfWeek, .monday)
        XCTAssertTrue(StandardEnvironment.locale.isMetric)

        XCTAssertEqual(push(5, [
            .enumeration(FormFactor.desktop.rawValue),
            .string("macOS"),
            .string("Mac14,9"),
            .string("Apple"),
            .string("Studio"),
            .string("26.0"),
            .enumeration(DeviceType.physical.rawValue),
        ]), 1)
        XCTAssertEqual(StandardEnvironment.device.formFactor, .desktop)
        XCTAssertEqual(StandardEnvironment.device.platform, "macOS")
        XCTAssertEqual(StandardEnvironment.device.model, "Mac14,9")
        XCTAssertEqual(StandardEnvironment.device.manufacturer, "Apple")
        XCTAssertEqual(StandardEnvironment.device.name, "Studio")
        XCTAssertEqual(StandardEnvironment.device.versionString, "26.0")
        XCTAssertEqual(StandardEnvironment.device.deviceType, .physical)

        XCTAssertEqual(push(6, [
            .string("Gallery"),
            .string("com.example.gallery"),
            .string("1.2"),
            .string("34"),
            .enumeration(Theme.dark.rawValue),
        ]), 1)
        XCTAssertEqual(StandardEnvironment.app.name, "Gallery")
        XCTAssertEqual(StandardEnvironment.app.packageName, "com.example.gallery")
        XCTAssertEqual(StandardEnvironment.app.versionString, "1.2")
        XCTAssertEqual(StandardEnvironment.app.buildString, "34")
        XCTAssertEqual(StandardEnvironment.app.requestedTheme, .dark)

        XCTAssertEqual(push(7, [
            .enumeration(ApplicationPhase.inactive.rawValue),
        ]), 1)
        XCTAssertEqual(StandardEnvironment.application.phase, .inactive)
    }
}
