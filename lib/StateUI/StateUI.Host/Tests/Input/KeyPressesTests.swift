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

    /// A navigation stack in a window: a page in it, and a sheet over it holding a page with a field taking the up
    /// arrow and following its focus - a sheet the stack keeps apart from its pages, as a slot.
    private func arranged() throws -> (runtime: HostRuntime, stack: MountedElement, field: MountedElement, front: MountedElement) {
        var field = element("field", .textField, takes: [.upArrow])
        field.events = .replace([.isFocusedChanged: 5])
        var body = element("body", .vStack, takes: [])
        body.children = .arranged([field])
        var presented = element("presented", .page, takes: [])
        presented.children = .arranged([body])
        var sheet = element("sheet", .sheet, takes: [])
        sheet.children = .arranged([presented])
        var under = element("under", .page, takes: [])
        under.children = .arranged([])
        var stack = element("stack", .navigationStack, takes: [])
        stack.children = .arranged([under, sheet])
        var window = element("window", .window, takes: [])
        window.children = .arranged([stack])
        let runtime = HostRuntime.still()
        runtime.tree.apply(window, complete: true)
        let mounted = try XCTUnwrap(runtime.tree.root?.first(id: .manual("stack")))
        return (
            runtime, mounted, try XCTUnwrap(mounted.first(id: .manual("field"))),
            try XCTUnwrap(mounted.first(id: .manual("presented"))))
    }

    /// The view holding the keyboard is found among everything an arrangement holds - the sheet it keeps apart from
    /// its pages included - and a key reaches it from there.
    func testTheHolderIsFoundInAnArrangementsSlot() throws {
        let (runtime, stack, field, front) = try arranged()
        XCTAssertEqual(stack.slots.map(\.type), [.sheet], "the stack keeps the sheet apart from its pages")
        let holder = KeyPresses.holder(under: stack) { $0 === field }
        XCTAssertTrue(holder === field, "the field in the sheet holds the keyboard")
        XCTAssertTrue(KeyPresses.target(of: .upArrow, modifiers: [], focused: holder, front: front) === field)
        withExtendedLifetime(runtime) {}
    }

    /// Where the focus stands is told to every element following it, in the sheet an arrangement keeps apart too.
    func testTheFocusIsReportedIntoAnArrangementsSlot() throws {
        let (runtime, stack, field, _) = try arranged()
        stack.reportFocus(in: runtime) { $0 === field }
        XCTAssertTrue(field.reportedFocus, "the field in the sheet heard where the focus stands")
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
