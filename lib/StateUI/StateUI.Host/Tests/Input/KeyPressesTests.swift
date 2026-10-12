// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// How every host routes a pressed key to the view taking it: out from the view holding the keyboard, else from
/// the page in front.
@MainActor
final class KeyPressesTests: XCTestCase {
    private func element(_ id: String, _ type: NodeType, takes keys: [Key], enabled: Bool = true) -> HostPatch {
        var element = HostPatch(id: .manual(id), type: type)
        if !keys.isEmpty { element.properties[.keysTaken] = keys.propValue }
        if !enabled { element.properties[.isEnabled] = .bool(false) }
        return element
    }

    /// A page holding a list taking Escape, a field in it taking the arrows, a disabled field taking Return and a
    /// button beside them taking "x".
    private func page() throws -> (runtime: HostRuntime, page: MountedElement) {
        var list = element("list", .vStack, takes: [.escape])
        list.children = .arranged([
            element("field", .textField, takes: [.upArrow, .downArrow]),
            element("off", .textField, takes: [.return], enabled: false),
            element("button", .button, takes: ["x"]),
        ])
        var page = element("page", .page, takes: [])
        page.children = .arranged([list])
        let runtime = HostRuntime.still()
        runtime.tree.apply(page, complete: true)
        return (runtime, try XCTUnwrap(runtime.tree.root))
    }

    private func named(_ id: String, in root: MountedElement) -> MountedElement? {
        root.id == .manual(id) ? root : root.children.lazy.compactMap { self.named(id, in: $0) }.first
    }

    func testAKeyReachesTheNearestViewTakingItOutFromTheKeyboard() throws {
        let (_, page) = try page()
        let field = named("field", in: page)
        XCTAssertEqual(KeyPresses.target(of: .upArrow, modifiers: [], focused: field, front: page)?.id, .manual("field"))
        XCTAssertEqual(KeyPresses.target(of: .escape, modifiers: [], focused: field, front: page)?.id, .manual("list"),
                       "the view holding the field")
        XCTAssertEqual(KeyPresses.target(of: .upArrow, modifiers: [.shift], focused: field, front: page)?.id,
                       .manual("field"), "Shift is the key's")
        XCTAssertNil(KeyPresses.target(of: "x", modifiers: [], focused: field, front: page), "a view beside it hears none")
        XCTAssertNil(KeyPresses.target(of: .upArrow, modifiers: [.primary], focused: field, front: page),
                     "held with the platform's own key, a shortcut's")
        XCTAssertNil(KeyPresses.target(of: .upArrow, modifiers: [.alt], focused: field, front: page))
    }

    func testWithNothingHoldingTheKeyboardThePagesContentHears() throws {
        let (_, page) = try page()
        XCTAssertEqual(KeyPresses.target(of: .escape, modifiers: [], focused: nil, front: page)?.id, .manual("list"))
        XCTAssertNil(KeyPresses.target(of: .upArrow, modifiers: [], focused: nil, front: page), "the field holds nothing")
    }

    func testADisabledViewTakesNoKey() throws {
        let (_, page) = try page()
        XCTAssertNil(KeyPresses.target(of: .return, modifiers: [], focused: named("off", in: page), front: page))
    }

    /// The element holding the keyboard is the deepest the toolkit says holds it; the keys a press would take are
    /// those of every view out from it.
    func testTheHolderIsTheDeepestAndTheKeysTakenAreItsAndAroundIt() throws {
        let (_, page) = try page()
        let holds: Set<ElementID> = [.manual("page"), .manual("list"), .manual("field")]
        let holder = KeyPresses.holder(under: page) { holds.contains($0.id) }
        XCTAssertEqual(holder?.id, .manual("field"))
        XCTAssertEqual(KeyPresses.taken(focused: holder, front: page), [.escape, .upArrow, .downArrow])
        XCTAssertEqual(KeyPresses.taken(focused: nil, front: page), [.escape], "the page's content alone")
        XCTAssertNil(KeyPresses.holder(under: page) { _ in false })
    }

    /// The keys a view takes cross once each, in StateUI's order, whatever order they were named in.
    func testTheKeysTakenCrossInOneOrder() {
        let keys: [Key] = ["b", .escape, "a", .upArrow, "b"]
        XCTAssertEqual(Key.ordered(keys), [.escape, .upArrow, "a", "b"])
    }
}
