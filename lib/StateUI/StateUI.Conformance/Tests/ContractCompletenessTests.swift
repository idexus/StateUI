// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIConformance
import XCTest

/// Every cell of the control dictionary has a case of its own contract's family, so a host's run gives its verdict on
/// every one: the element itself, each of its own members, and each tier's member on every element wearing the tier.
@MainActor
final class ContractCompletenessTests: XCTestCase {
    /// Every contract has one family, named for it, and every family is a contract's.
    func testEveryContractHasOneFamily() {
        // Closures, not key paths: a key path through an existential metatype crashes Swift 6.4's SILGen.
        let contracts = LibraryContracts.tiers.map { $0.name } + LibraryContracts.elements.map { $0.name }
        let families = Families.all.map { $0.name }

        XCTAssertEqual(families.sorted(), contracts.sorted())
        XCTAssertEqual(Set(families).count, families.count, "a contract with two families")
    }

    /// An element's family covers the element itself and each of its own members.
    func testEveryElementsFamilyCoversItAndEachOfItsMembers() {
        for element in LibraryContracts.elements {
            let name = element.name
            let covered = Set(Self.covers(of: name).filter { $0.element == name && $0.tier == nil }.map { $0.member ?? "" })
            let missing = ([""] + element.members.map { $0.name }).filter { !covered.contains($0) }

            XCTAssertEqual(missing.map { $0.isEmpty ? name : "\(name).\($0)" }, [], "\(name)Tests has no case of these")
        }
    }

    /// A tier's family covers each of its members on every element wearing the tier.
    func testEveryTiersFamilyCoversEachMemberOnEveryWearer() {
        for tier in LibraryContracts.tiers {
            let covered = Set(Self.covers(of: tier.name).filter { $0.tier == tier.name }.map(\.description))
            let wearers = LibraryContracts.elements.filter { element in
                element.tiers.contains { ObjectIdentifier($0) == ObjectIdentifier(tier) }
                    || element.worn.contains { ObjectIdentifier($0) == ObjectIdentifier(tier) }
            }
            let missing = wearers.flatMap { wearer in tier.members.map { "\(wearer.name).\($0.name)" } }
                .filter { !covered.contains($0) }

            XCTAssertEqual(missing, [], "\(tier.name)Tests has no case of these")
        }
    }

    /// A FAMILY PROVES ITS OWN CONTRACT ALONE: an element's family the element and its own members, a tier's its
    /// members on their wearers. Another contract's member a case leans on is what it needs - a verdict standing in
    /// another family's file would outlive that family's revision, an old ❌ staying in its cell after the fix.
    func testEveryCaseProvesItsOwnFamilysContractAlone() {
        var foreign: [String] = []
        for family in Families.all {
            let isTier = LibraryContracts.tiers.contains { $0.name == family.name }
            for each in family.cases {
                for covered in each.proves {
                    let own = isTier ? covered.tier == family.name : covered.element == family.name && covered.tier == nil
                    if !own { foreign.append("\(family.name)/\(each.name): \(covered)") }
                }
            }
        }
        XCTAssertEqual(foreign, [], "\(foreign.count) cases prove another family's contract")
    }

    /// Every case a family holds covers something, and has a name no other case of the family has.
    func testEveryCaseCoversSomethingUnderANameOfItsOwn() {
        for family in Families.all {
            let names = family.cases.map(\.name)
            XCTAssertEqual(Set(names).count, names.count, "\(family.name)Tests names two cases alike")
            XCTAssertEqual(family.cases.filter { $0.proves.isEmpty }.map(\.name), [], "\(family.name)Tests")
        }
    }

    /// What the cases of the family named `name` cover.
    private static func covers(of name: String) -> [Covered] {
        Families.all.first { $0.name == name }?.cases.flatMap(\.proves) ?? []
    }
}
