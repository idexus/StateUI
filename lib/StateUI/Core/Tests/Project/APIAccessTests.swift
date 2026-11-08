// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

final class APIAccessTests: XCTestCase {
    private static let facts: [(make: String, names: [String])] = [
        ("AccessibilitySettings()", ["reducesMotion", "prefersHigherContrast", "isScreenReaderOn", "textScale"]),
        ("ApplicationInfo()", ["name", "packageName", "version", "build", "colorScheme", "accentColor"]),
        ("ApplicationSession()", ["phase"]),
        ("Battery()", ["chargeLevel", "state", "powerSource", "energySaverStatus"]),
        ("Connectivity()", ["networkAccess", "connectionProfiles"]),
        ("DeviceDisplay()", ["width", "height", "density", "orientation", "rotation", "refreshRate"]),
        ("DeviceInfo()", ["formFactor", "platform", "model", "manufacturer", "name", "platformVersion", "isVirtual"]),
        ("Gate(.ignoreWhileRunning)", ["isBusy"]),
        ("LocaleInfo()", ["language", "languages", "timeZone", "uses24HourClock", "firstDayOfWeek", "isMetric", "writingDirection"]),
        ("SceneSession()", ["phase"]),
        ("Ticker(every: .seconds(1))", ["ticks", "isRunning"]),
        ("WindowSession()", ["phase"]),
    ]

    private static let settings: [(make: String, names: [String])] = [
        ("ApplicationSession()", ["colorScheme", "accentColor", "styles", "motion"]),
        ("Ticker(every: .seconds(1))", ["limit"]),
        ("WindowSession()", ["title", "x", "y", "width", "height", "minimumWidth", "minimumHeight", "maximumWidth",
                             "maximumHeight", "isMaximizable", "isMinimizable", "background"]),
    ]

    func testFactsAreReadableButHaveNoPublicWriteOrProjection() throws {
        try clients { check in
            let reads = Self.facts.flatMap { fact in fact.names.map { "_ = \(fact.make).\($0)" } }.joined(separator: "\n")
            XCTAssertNil(try check(Self.onActor(reads)), "a client can construct providers and read their facts")

            for fact in Self.facts {
                for name in fact.names {
                    let direct = try check(Self.onActor("let owner = \(fact.make); owner.\(name) = owner.\(name)"))
                    XCTAssertNotNil(direct, "\(fact.make).\(name) has a public setter")
                    XCTAssertTrue(direct?.contains("setter is inaccessible") == true, direct ?? "no diagnostic")

                    let projected = try check(Self.onActor("_ = \(fact.make).$\(name)"))
                    XCTAssertNotNil(projected, "\(fact.make).$\(name) lends a fact for writing")
                    XCTAssertTrue(projected?.contains("$\(name)") == true, projected ?? "no diagnostic")
                }
            }
        }
    }

    func testApplicationSettingsKeepTheirWritableBindings() throws {
        try clients { check in
            let writes = Self.settings.map { setting in
                "do { let owner = \(setting.make);\n"
                    + setting.names.map { "owner.$\($0).wrappedValue = owner.\($0)" }.joined(separator: "\n") + "\n}"
            }.joined(separator: "\n")
            XCTAssertNil(try check(Self.onActor(writes)))
        }
    }

    func testTheClientReadsSessionFactsOnMainActor() throws {
        try clients { check in
            let read = "func read(_ application: ApplicationSession) { _ = application.phase }"
            XCTAssertNil(try check("@MainActor " + read))
            let outside = try check(read)
            XCTAssertNotNil(outside)
            XCTAssertTrue(outside?.contains("actor-isolated") == true, outside ?? "no diagnostic")
        }
    }

    private static func onActor(_ source: String) -> String {
        "@MainActor func client() {\n\(source)\n}"
    }

    private func clients(_ body: (_ check: (String) throws -> String?) throws -> Void) throws {
        let modules = try XCTUnwrap(APISurfaceTests.builtModules())
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-api-clients-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let file = scratch.appendingPathComponent("Client.swift")
        var arguments = ["-typecheck", "-swift-version", "6", "-warnings-as-errors", "-I", modules.path,
                         "-target", try APISurfaceTests.triple(), "-module-cache-path", scratch.appendingPathComponent("cache").path,
                         file.path]
        if let sdk = try APISurfaceTests.sdk() { arguments += ["-sdk", sdk] }
        try body { source in
            try ("import StateUI\n" + source + "\n").write(to: file, atomically: true, encoding: .utf8)
            do {
                _ = try APISurfaceTests.run("swiftc", arguments)
                return nil
            } catch let error as NSError where error.domain == "StateUI.Compiler" {
                return error.userInfo[NSDebugDescriptionErrorKey] as? String ?? error.description
            }
        }
    }
}
