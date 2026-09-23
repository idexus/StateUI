// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What this runtime says about itself, written to exports/ and held to it.
//
// The registrations ARE the declaration: nothing here is written by hand, so
// nothing here can disagree with the code. What it says is PRESENCE - which
// member this host realizes on which element - never ownership, which the
// contracts answer when the documents are rendered.
//
// Run with STATEUI_UPDATE_EXPORTS=1 to write the export instead of checking
// it, then read the .txt sidecar in the diff.

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitDeclarationExportTests: XCTestCase {
    /// The export is what the registry says, to the byte and to the line.
    @MainActor
    func testWhatThisHostDeclaresIsWhatItExports() throws {
        let declaration = Self.declaration()
        let bytes = Wire.encodeDeclaration(declaration)
        let sidecar = Self.sidecar(of: declaration)
        let binary = Self.exports.appendingPathComponent("appkit.bin")
        let text = Self.exports.appendingPathComponent("appkit.txt")

        if ProcessInfo.processInfo.environment["STATEUI_UPDATE_EXPORTS"] == "1" {
            try FileManager.default.createDirectory(
                at: Self.exports, withIntermediateDirectories: true)
            try Data(bytes).write(to: binary)
            try sidecar.write(to: text, atomically: true, encoding: .utf8)
            return
        }

        let hint = """


            Either a registration changed - in which case run the suite again \
            with STATEUI_UPDATE_EXPORTS=1 and read the diff - or something \
            stopped being realized.
            """

        XCTAssertEqual(Data(bytes), try Data(contentsOf: binary), "exports/appkit.bin\(hint)")
        XCTAssertEqual(
            sidecar, try String(contentsOf: text, encoding: .utf8), "exports/appkit.txt\(hint)")
    }

    /// The export is deterministic: the same registry writes the same bytes.
    @MainActor
    func testTheSameRegistryWritesTheSameBytes() {
        XCTAssertEqual(
            Wire.encodeDeclaration(Self.declaration()),
            Wire.encodeDeclaration(Self.declaration()))
    }

    /// Every name in the export is one the contracts declare - a host and the
    /// contracts disagreeing is a mistake on one side, never a row to render.
    @MainActor
    func testEveryNameInTheExportIsOneTheContractsKnow() {
        let unknown = Self.declaration().undeclared

        XCTAssertTrue(
            unknown.isEmpty,
            "the AppKit export names what no contract declares: "
                + unknown.map { "\($0.element).\($0.member)" }.joined(separator: ", "))
    }

    /// Every member the export calls SHARED is one the registry realizes on
    /// every element wearing the contract declaring it.
    ///
    /// The two halves are written twice - the registry takes a member typed,
    /// one call each, while the export takes names - so this holds the reading
    /// half to the registered one. It cannot be asked the other way round: a
    /// registry does not keep WHERE a member came from, so a tier whose every
    /// wearer is registered - `InputView` over the three fields, `Shape` over
    /// the six shapes - looks exactly like shared machinery from here, and is
    /// not.
    @MainActor
    func testEverySharedMemberIsRealizedOnEveryWearer() {
        let realization = AppKitRegistrations.registry.realization

        for member in AppKitRegistrations.sharedMembers + AppKitRegistrations.sharedEvents {
            guard let contract = LibraryContracts.all.first(where: { owner in
                owner.members.contains { $0.name == member.name }
            }) else {
                XCTFail("no contract declares the shared member `\(member.name)`")
                continue
            }

            let wearers = Self.ofTheLibrary(realization.elements).filter { element in
                LibraryContracts.elements
                    .first { $0.nodeType.name == element }?
                    .worn.contains { ObjectIdentifier($0) == ObjectIdentifier(contract) } == true
            }
            // Both sides of the comparison are the LIBRARY's elements. The
            // registry spreads a shared member over everything wearing its
            // contract, an application's own element included, and that one is
            // not this host's to declare.
            let realized = Self.ofTheLibrary(Set(
                realization.members
                    .filter { $0.owner == contract.name && $0.member == member.name }
                    .map(\.element)))

            XCTAssertEqual(
                realized, wearers,
                "`\(contract.name).\(member.name)` is declared shared, and the registry realizes "
                    + "it on \(realized.count) of the \(wearers.count) elements wearing it")
        }
    }

    /// The declaration carries the three kinds apart: what a control takes,
    /// what it raises, and what the host performs.
    @MainActor
    func testTheDeclarationCarriesMembersEventsAndActs() throws {
        let declaration = Self.declaration()
        let slider = try XCTUnwrap(declaration.elements["Slider"])

        XCTAssertTrue(slider.members.isSuperset(of: ["value", "minimum", "maximum"]))
        XCTAssertTrue(slider.events.contains("valueChanged"))
        XCTAssertTrue(declaration.shared.members.contains("margin"))
        XCTAssertTrue(declaration.shared.events.contains("tapped"))
        XCTAssertTrue(declaration.acts.isSuperset(of: ["focus", "unfocus", "persistValue"]))
    }

    // MARK: - Support

    /// `exports`, a directory of its own: every fixture is authored by the
    /// core's tests, while an export is written by a RUNTIME saying what it
    /// realizes.
    private static var exports: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // Registration
            .deletingLastPathComponent()    // Tests
            .deletingLastPathComponent()    // StateUI.AppKit
            .deletingLastPathComponent()    // lib
            .deletingLastPathComponent()    // the repository
            .appendingPathComponent("exports")
    }

    /// Which kind each member of each contract is, by name - what tells a
    /// property from an event once a realization holds only names.
    private static let kinds: [String: MemberFacts.Kind] = {
        var kinds: [String: MemberFacts.Kind] = [:]

        for contract in LibraryContracts.all {
            for case let member as any DeclaredMember in contract.members {
                kinds[member.name] = member.facts.kind
            }
        }

        return kinds
    }()

    /// What this host declares, read off its registry.
    ///
    /// The registry answers a REALIZATION - the shared machinery already
    /// spread over every element wearing it. A declaration is the other shape:
    /// presence per element, with the shared half said once. So the shared
    /// half is READ from where it was declared, and what is left on each
    /// element is that element's own.
    ///
    /// It cannot be worked out from the realization instead - "a member every
    /// element has" is empty here, because `Page` and `SplitView` wear no
    /// `ViewContract` and take none of the view tier at all.
    /// What an export is ABOUT: the elements of the LIBRARY. An application
    /// registers elements of its own with this host too - a control it wrote,
    /// realized by a view it wrote - and those are the application's, not this
    /// host's to declare. They are left out here rather than filtered where
    /// the bytes are written, because this is where the question belongs: an
    /// export says which of the library's elements this host presents.
    private static func ofTheLibrary(_ elements: Set<String>) -> Set<String> {
        elements.filter { element in
            LibraryContracts.elements.contains { $0.nodeType.name == element }
        }
    }

    @MainActor
    private static func declaration() -> HostDeclaration {
        let realization = AppKitRegistrations.registry.realization
        let shared = Set(
            (AppKitRegistrations.sharedMembers + AppKitRegistrations.sharedEvents).map(\.name))
        var byElement: [String: Set<String>] = [:]

        for element in ofTheLibrary(realization.elements) {
            byElement[element] = []
        }

        for member in realization.members where byElement[member.element] != nil {
            byElement[member.element, default: []].insert(member.member)
        }

        var declaration = HostDeclaration()
        declaration.shared = split(shared)

        for (element, members) in byElement {
            declaration.elements[element] = split(members.subtracting(shared))
        }

        declaration.acts = Set(AppKitRegistrations.acts.map(\.name))
        return declaration
    }

    /// Names split into what a view takes and what it raises, as the contracts
    /// declare each. A name no contract knows is kept as a member, where
    /// `undeclared` names it rather than losing it quietly.
    private static func split(_ names: Set<String>) -> HostDeclaration.Element {
        HostDeclaration.Element(
            members: names.filter { kinds[$0] != .event },
            events: names.filter { kinds[$0] == .event })
    }

    /// The readable half a review diff reads: one line per element, its
    /// members and then its events under it, an event told from a property by
    /// the parentheses every handler is called with.
    private static func sidecar(of declaration: HostDeclaration) -> String {
        var lines: [String] = []

        for element in declaration.elements.keys.sorted() {
            lines.append(element)
            lines += under(declaration.elements[element] ?? HostDeclaration.Element())
        }

        lines.append("(every element)")
        lines += under(declaration.shared)

        lines.append("(acts)")
        lines += declaration.acts.sorted().map { "  \($0)()" }

        return lines.joined(separator: "\n") + "\n"
    }

    /// One indented line per member and then per event, each sorted.
    private static func under(_ element: HostDeclaration.Element) -> [String] {
        element.members.sorted().map { "  \($0)" }
            + element.events.sorted().map { "  \($0)()" }
    }
}

#endif
