// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The STANDARD ENVIRONMENT: the host's providers, seeded into every walk's
// scope and written through `stateui_set_environment`.
//
// The mechanism is Types/HostEnvironment.swift (the providers and the
// applier), the seeding in Core/Diff.swift and `Node.built`, and the export
// in Bridge/Exports.swift. The promises pinned here:
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
@testable import StateUI

/// Reads the battery - the view a push should rebuild.
private struct BatteryLabel: ContentView {
    @Environment var battery: Battery

    var content: Element {
        label("\(Int(battery.chargeLevel * 100))% \(battery.state)")
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

    var content: Element {
        label(fits ? "fits" : "too wide")
    }
}

/// Reads nothing of the environment - the view a push must leave alone.
private struct Bystander: ContentView {
    let builds: Builds

    var content: Element {
        builds.count += 1
        return label("still")
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
    @Environment var window: WindowInfo
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
        StandardEnvironment.device.idiom = .unknown
        StandardEnvironment.window.phase = .activated
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
        XCTAssertTrue(app.window === StandardEnvironment.window)
    }

    // MARK: - The domains

    func testTheWindowPhaseFollowsTheHost() {
        XCTAssertEqual(StandardEnvironment.window.phase, .activated)

        XCTAssertEqual(push(7, [.enumeration(WindowPhase.stopped.rawValue)]), 1)
        XCTAssertEqual(StandardEnvironment.window.phase, .stopped)

        XCTAssertEqual(push(7, [.enumeration(WindowPhase.deactivated.rawValue)]), 1)
        XCTAssertEqual(StandardEnvironment.window.phase, .deactivated)
    }

    func testTheDevicePushCarriesTheIdiom() {
        // The platform is the one value here that is TEXT - MAUI's
        // DevicePlatform is a struct anyone can Create(String), so the
        // vocabulary is open and rides its spelling.
        XCTAssertEqual(push(5, [
            .enumeration(DeviceIdiom.desktop.rawValue), .string("MacCatalyst"),
            .string("Mac14,9"), .string("Apple"), .string("mac"), .string("14.5"),
            .enumeration(DeviceType.physical.rawValue),
        ]), 1)

        XCTAssertEqual(StandardEnvironment.device.idiom, .desktop)
        XCTAssertEqual(StandardEnvironment.device.deviceType, .physical)

        // An idiom this library has no case for degrades to .unknown - the
        // host is at most a release newer, and unknown shows everything.
        XCTAssertEqual(push(5, [
            .enumeration(99), .string(""), .string(""),
            .string(""), .string(""), .string(""),
            .enumeration(DeviceType.unknown.rawValue),
        ]), 1)
        XCTAssertEqual(StandardEnvironment.device.idiom, .unknown)
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
    /// Spelled out rather than derived, which is the point - `WireEnumTests`
    /// reads these very declarations to hold the C# mirrors against them, so
    /// a case slipped into the middle would renumber both sides together and
    /// agree perfectly about the wrong thing. This is the line that notices.
    func testTheEnumsKeepTheNumbersTheyDeclare() {
        XCTAssertEqual(BatteryState.charging.rawValue, 1)
        XCTAssertEqual(BatteryState.notPresent.rawValue, 5)
        XCTAssertEqual(BatteryPowerSource.wireless.rawValue, 4)
        XCTAssertEqual(EnergySaverStatus.on.rawValue, 1)
        XCTAssertEqual(NetworkAccess.internet.rawValue, 4)
        XCTAssertEqual(ConnectionProfile.wiFi.rawValue, 4)
        XCTAssertEqual(DisplayOrientation.landscape.rawValue, 2)
        XCTAssertEqual(DisplayRotation.rotation270.rawValue, 4)
        XCTAssertEqual(AppTheme.dark.rawValue, 2)
        XCTAssertEqual(DeviceType.virtual.rawValue, 2)
        XCTAssertEqual(Weekday.saturday.rawValue, 6)
        XCTAssertEqual(DeviceIdiom.desktop.rawValue, 3)
        XCTAssertEqual(WindowPhase.stopped.rawValue, 2)
    }

    // MARK: - The names

    /// A standard provider stands for a MAUI class, so its properties are
    /// MAUI's, camelCased - the rule the whole library follows, checked here
    /// because THIS is the surface where the shorter name is tempting: an
    /// application resolves several providers at once and reads them side by
    /// side, so `device.name` beside `app.name` looks as though it wanted
    /// distinguishing. It does not. The object in front of the dot says which,
    /// and `DeviceInfo.Name` is what somebody who knows MAUI will look for.
    ///
    /// Measured 2026-08-15, when four had drifted and nothing named them:
    /// `deviceName` for `Name`, `version` for `VersionString` twice over, and
    /// `profiles` for `ConnectionProfiles`.
    ///
    /// **A `.NET:` line is deliberately not checked.** `LocaleInfo` is this
    /// library's own object over CultureInfo, RegionInfo and TimeZoneInfo -
    /// there is no MAUI class to be named after, and `region` for
    /// `TwoLetterISORegionName` is the whole point of it existing.
    func testEveryProviderPropertyIsNamedAfterItsMauiMember() throws {
        guard let source = try Fixtures.allSources()
            .first(where: { $0.path.hasSuffix("Types/HostEnvironment.swift") })
        else {
            return XCTFail("Types/HostEnvironment.swift is no longer where the providers live")
        }

        var doc: [String] = []
        var checked = 0
        var wrong: [String] = []

        for line in source.text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.drop(while: { $0 == " " })

            if trimmed.hasPrefix("///") {
                // TRIMMED before it is joined, and that is not tidiness: four
                // of these docs end a line with `MAUI:` and start the next with
                // the class, so joining the lines as they stand puts TWO spaces
                // in the middle of the very thing being read.
                doc.append(trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces))
                continue
            }

            defer { doc = [] }

            guard trimmed.hasPrefix("public var ") else { continue }

            let said = doc.joined(separator: " ")
            guard said.contains("MAUI:") else { continue }

            let name = String(
                trimmed.dropFirst("public var ".count).prefix { $0.isLetter || $0.isNumber })

            guard let member = Self.mauiMember(in: said) else {
                wrong.append("`\(name)` says MAUI: and then nothing this can read as a member")
                continue
            }

            checked += 1

            let expected = member.prefix(1).lowercased() + member.dropFirst()

            if name != expected {
                wrong.append("`\(name)` stands for \(member) and should be `\(expected)`")
            }
        }

        XCTAssertTrue(wrong.isEmpty, """
            \(wrong.joined(separator: "\n"))

            A provider's properties are MAUI's own, camelCased - the `///` above \
            each one says which member it stands for, and that is the name it \
            takes. A shorter one reads better on its own and worse in a file \
            where somebody is looking for what MAUI called it.
            """)

        // Not vacuous: the whole check hangs off a comment being read, so a
        // `///` that stopped saying `MAUI:` would quietly check nothing. There
        // are 24 - the eight it does not check are `LocaleInfo`'s seven, which
        // name .NET members, and the window phase, which MAUI has no answer to.
        XCTAssertEqual(checked, 24, "the providers stopped naming their MAUI members")
    }

    /// The member a `///` says a property stands for - `MAUI: DeviceInfo.Name.`
    /// gives `Name` - or nil where it names none.
    ///
    /// A CLASS on its own does not count: `MAUI: Connectivity -
    /// Microsoft.Maui.Networking.` is a type's own doc, and reading the first
    /// dot in it would ask a property to be called `maui`.
    private static func mauiMember(in doc: String) -> String? {
        guard let marker = doc.range(of: "MAUI: ") else { return nil }

        let rest = doc[marker.upperBound...]
        let type = rest.prefix { $0.isLetter || $0.isNumber }

        guard !type.isEmpty, rest.dropFirst(type.count).first == "." else { return nil }

        let member = rest.dropFirst(type.count + 1).prefix { $0.isLetter || $0.isNumber }

        return member.isEmpty ? nil : String(member)
    }
}
