// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// An application registers with this host through the registries named as the
/// MAUI host names its own: `StateUIControls.add`, `StateUIActs.add` and
/// `StateUIEvents.raise` - and through nothing beside them.
///
/// Every spelling those names replaced is written here the way an application
/// would have written it, and must NOT compile against this host's public
/// module; the registry's spelling, beside it, must. The pair is what makes the
/// refusal mean something: the two listings differ in that one spelling, so a
/// failure is the spelling's and never a typo's.
///
/// Compiled as an application's AppKit head compiles - `import StateUI` and
/// `import StateUIAppKit` - against the modules this package's build wrote.
final class AppKitRegistrationRoadsTests: XCTestCase {
    /// A spelling taken away, and the registry's spelling for the same thing.
    private struct Road {
        let name: String
        let removed: String
        let registry: String
    }

    /// An application's own control, acts and event - what every listing leans
    /// on, declared the way an application declares them.
    private static let declarations = """
        enum LampContract: ElementContract {
            static let nodeType: NodeType = "Test.Lamp"
            static let tiers: [any Contract.Type] = [ViewContract.self]

            static let lit = ElementProperty<Self, Bool>("lit")
            static let flash = ElementAct<Self, Void, Void>("Test.Flash")

            static let members: [any ContractMember] = [lit, flash]
        }

        final class LampView: NSView {}

        enum NotesContract: ApplicationTier {
            static let name = "Notes"

            static let log = ElementAct<Self, String, Void>("Notes.Log")
            static let changed = ElementEvent<Self, Bool>("Notes.Changed")

            static let members: [any ContractMember] = [log, changed]
        }
        """

    /// Each spelling the registries replaced, beside the registry's own.
    private static let roads = [
        Road(
            name: "a control added through the host's own name",
            removed: "StateUIAppKit.realizes(LampContract.self, create: { _ -> LampView in LampView() })",
            registry: "StateUIControls.add(LampContract.self, create: { _ -> LampView in LampView() })"),
        Road(
            name: "an act of the application's",
            removed: "StateUIAppKit.performs(NotesContract.log) { _ in }",
            registry: "StateUIActs.add(NotesContract.log) { _ in }"),
        Road(
            name: "an act aimed at a control",
            removed: "StateUIAppKit.performs(LampContract.flash, on: LampView.self) { _ in }",
            registry: "StateUIActs.add(LampContract.flash, on: LampView.self) { _ in }"),
        Road(
            name: "an event of the application's",
            removed: "StateUIAppKit.raise(NotesContract.changed, true)",
            registry: "StateUIEvents.raise(NotesContract.changed, true)"),
        Road(
            name: "the handle a control's members are registered on",
            removed: "let _: ((AppKitRealizing<LampContract, LampView>) -> Void)? = nil",
            registry: "let _: ((AppKitRegistration<LampContract, LampView>) -> Void)? = nil"),
    ]

    func testEveryRemovedSpellingIsClosedAndItsRegistryOpen() throws {
        // Beside the test bundle: in the folder it stands in, where Swift Build
        // puts every product, or in a Modules folder there.
        let bundle = Bundle(for: Self.self).bundleURL
        guard let modules = [bundle, bundle.deletingLastPathComponent()]
            .flatMap({ [$0, $0.appendingPathComponent("Modules")] })
            .first(where: { FileManager.default.fileExists(atPath: $0.appendingPathComponent("StateUIAppKit.swiftmodule").path) })
        else {
            // Never a skip: a check that did not run reads as one that passed.
            return XCTFail("no StateUIAppKit.swiftmodule beside the test bundle - no road was checked")
        }

        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("stateui-appkit-roads-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let listings = Self.roads.flatMap { road in
            [(road: road.name, compiles: false, source: road.removed),
             (road: road.name, compiles: true, source: road.registry)]
        }
        let files = try listings.enumerated().map { index, listing in
            let file = scratch.appendingPathComponent("road_\(index).swift")
            try Data(Self.file(around: listing.source).utf8).write(to: file)
            return file
        }

        let outputs = Outputs(count: files.count)
        DispatchQueue.concurrentPerform(iterations: files.count) { index in
            outputs.set(index, Self.typecheck(files[index], modules: modules))
        }

        for (index, listing) in listings.enumerated() {
            let output = outputs.value(index)

            if listing.compiles {
                XCTAssertNil(output, "\(listing.road): the registry's spelling does not compile:\n\(output ?? "")")
            } else {
                XCTAssertNotNil(output, "\(listing.road) compiles again - an application registers "
                    + "through StateUIControls, StateUIActs and StateUIEvents alone")
            }
        }
    }

    /// A listing as a file an application's AppKit head could hold.
    private static func file(around listing: String) -> String {
        "import AppKit\nimport StateUI\nimport StateUIAppKit\n\n\(declarations)\n\n@MainActor\nfunc road() {\n    \(listing)\n}\n"
    }

    /// Type-checks one file: the compiler's errors where it failed, nil where it passed.
    private static func typecheck(_ file: URL, modules: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["swiftc", "-typecheck", "-parse-as-library", "-I", modules.path, file.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do { try process.run() } catch { return "could not run swiftc: \(error)" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus != 0 else { return nil }
        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .filter { $0.contains("error:") }
            .prefix(4)
            .joined(separator: "\n")
    }

    /// The outputs of listings checked at once, each written by its own index.
    private final class Outputs: @unchecked Sendable {
        private var values: [String?]
        private let lock = NSLock()

        init(count: Int) {
            values = Array(repeating: nil, count: count)
        }

        func set(_ index: Int, _ value: String?) {
            lock.withLock { values[index] = value }
        }

        func value(_ index: Int) -> String? {
            lock.withLock { values[index] }
        }
    }
}
