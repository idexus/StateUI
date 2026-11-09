// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

@MainActor
final class IntegerBoundsTests: XCTestCase {
    private let invalid: [Double] = [
        Double(Int.max).nextUp.rounded(.up), Double(Int.min).nextDown.rounded(.down), .infinity, -.infinity, .nan,
    ]

    func testInvalidGridNumbersUseTheirAbsentValues() throws {
        for number in invalid {
            let runtime = HostRuntime.still()
            runtime.tree.apply(node("item", .text, [
                .gridRow: .number(number), .gridColumn: .number(number),
                .gridRowSpan: .number(number), .gridColumnSpan: .number(number),
            ]), complete: true)
            let values = try XCTUnwrap(runtime.tree.root).layoutValues
            XCTAssertEqual(values.row, 0)
            XCTAssertEqual(values.column, 0)
            XCTAssertEqual(values.rowSpan, 1)
            XCTAssertEqual(values.columnSpan, 1)
            withExtendedLifetime(runtime) {}
        }
    }

    func testInvalidChromeOrdersKeepDeclarationOrder() throws {
        for number in invalid {
            let runtime = HostRuntime.still()
            runtime.tree.apply(node("root", .vStack, children: [
                node("first", .toolbarGroup, [ToolbarGroupContract.order.token: .number(number)], children: [node("one", .toolbarButton)]),
                node("second", .toolbarGroup, children: [node("two", .toolbarButton)]),
                node("barOne", .menuBar, [MenuBarContract.order.token: .number(number)], children: [node("menuOne", .menu, [.text: .string("One")])]),
                node("barTwo", .menuBar, children: [node("menuTwo", .menu, [.text: .string("Two")])]),
            ]), complete: true)
            let children = try XCTUnwrap(runtime.tree.root).children
            let actions = ChromeActions(children.prefix(2).map {
                ChromeActions.Declared($0, depth: 0, declarersPart: .detail)
            }, part: nil, sidebarShown: true)
            XCTAssertEqual(actions.primary.map(\.id), [.manual("one"), .manual("two")])
            let menus = ChromeMenus(children.suffix(2).map { (element: $0, level: 0) })
            XCTAssertEqual(menus.menus.map(\.title), ["One", "Two"])
            withExtendedLifetime(runtime) {}
        }
    }

    func testInvalidTabNumbersChooseTheFirstTab() throws {
        for number in invalid {
            let runtime = HostRuntime.still()
            runtime.tree.apply(node("tabs", .tabView, [.selectedTab: .number(number)], children: [
                node("first", .page), node("second", .page),
            ]), complete: true)
            XCTAssertEqual(try XCTUnwrap(runtime.tree.root).selectedTab?.id, .manual("first"))
            withExtendedLifetime(runtime) {}
        }
    }

    func testInvalidQuestionNumbersLeaveNoIndexOrLimit() throws {
        for number in invalid {
            let choice = try XCTUnwrap(HostQuestion(HostActCall(
                act: .chooseAction, arguments: HostActCall.usersWindow + [
                    .string("Choose"), ["One", "Two"].propValue, .number(number),
                ], completion: nil)))
            XCTAssertNil(choice.destructive)
            let prompt = try XCTUnwrap(HostQuestion(HostActCall(
                act: .prompt, arguments: HostActCall.usersWindow + [
                    .string("Type"), .nothing, .nothing, .nothing, .nothing, .number(number),
                ], completion: nil)))
            XCTAssertNil(prompt.maximumLength)
        }
        let past = try XCTUnwrap(HostQuestion(HostActCall(
            act: .prompt, arguments: HostActCall.usersWindow + [
                .string("Type"), .nothing, .nothing, .nothing, .nothing, .number(Double(Int32.max) + 1),
            ], completion: nil)))
        XCTAssertNil(past.maximumLength, "a bound past a toolkit's 32-bit count is none")
    }

    func testValidWholeNumbersKeepTheContractsRoundingAndSign() throws {
        let runtime = HostRuntime.still()
        runtime.tree.apply(node("item", .text, [
            .gridRow: .number(2.6), .gridColumn: .number(-2.6), .gridRowSpan: .number(3.4), .gridColumnSpan: .number(-4),
        ]), complete: true)
        let values = try XCTUnwrap(runtime.tree.root).layoutValues
        XCTAssertEqual(values.row, 3)
        XCTAssertEqual(values.column, -3)
        XCTAssertEqual(values.rowSpan, 3)
        XCTAssertEqual(values.columnSpan, 1)
        withExtendedLifetime(runtime) {}
    }

    func testChoiceLanesOutsideTheirIntegerRangeHaveNoValue() {
        for number in [Double(Int32.max) + 1, Double(Int32.min) - 1, .infinity, -.infinity, .nan] {
            XCTAssertNil(MountedElement.value(of: [number], as: .choice))
        }
        XCTAssertEqual(MountedElement.value(of: [3.6], as: .choice), .enumeration(4))
        XCTAssertEqual(MountedElement.value(of: [Double(Int32.min)], as: .choice), .enumeration(Int32.min))
    }

    func testAnAimedNumberOutsideIntIsRefusedAsAnInvalidTarget() throws {
        let runtime = HostRuntime.still()
        runtime.tree.apply(node("view", .button), complete: true)
        for number in invalid {
            XCTAssertThrowsError(try runtime.tree.aimed(HostActCall(
                act: .focus, arguments: [.number(number)], completion: nil))) { error in
                XCTAssertEqual((error as? ActFailure)?.reason, "FocusElement.focus has to say which view it is for")
            }
        }
    }

    private func node(
        _ id: String, _ type: NodeType, _ properties: [Prop: HostValue] = [:], children: [HostPatch] = []
    ) -> HostPatch {
        var patch = HostPatch(id: .manual(id), type: type)
        patch.properties = properties
        patch.children = .arranged(children)
        return patch
    }
}
