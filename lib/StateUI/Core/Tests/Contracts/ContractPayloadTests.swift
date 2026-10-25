// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Every event a library contract declares, with a payload shaped the way the
// hosts send it: each decodes through the types its member declares, and the
// table names every event member - so an event added without its payload
// fails here, and a payload its declaration refuses is found here rather than
// as a handler that never runs.

import XCTest
@_spi(Host) @testable import StateUI

@MainActor
final class ContractPayloadTests: XCTestCase {
    /// The events the table checked, as `Contract.member`.
    private var checked: Set<String> = []

    /// Every event member's payload, as the hosts send it, decodes through the
    /// types it declares - and the table is every event member.
    func testEveryEventMembersPayloadDecodesAsDeclared() {
        let frame: [Double] = [0, 0, 100, 40, 0, 0, 100, 40]
        let address = PropValue.string("https://example.com")

        // What the tiers and mixins report.
        check(FocusElementContract.isFocusedChanged, [.bool(true)])
        check(ViewContract.dragLeave)
        check(ViewContract.dragOver)
        check(ViewContract.dragStarting)
        check(ViewContract.drop, [.string("dropped")])
        check(ViewContract.filesDropped, [[ChosenFile(address: "/Reports/Report.txt", name: "Report.txt")].propValue])
        check(ViewContract.dragEnded)
        check(ViewContract.frameChanged, [.numbers(frame)])
        check(ViewContract.panUpdated, [.enumeration(1), .number(3), .number(4)])
        check(LayoutEngineContract.handMoved, [.enumeration(2), .numbers([-4, 0]), .numbers([-300, 0])])
        check(LayoutEngineContract.handStepped, [.numbers([-1, 0])])
        check(LayoutEngineContract.itemMoved, [.enumeration(1), .numbers([75, 40]), .numbers([0, 0]), .number(500)])
        check(LayoutEngineContract.pinchMoved, [.enumeration(1), .number(1.5), .number(30), .numbers([0, 0])])
        check(ViewContract.pinchUpdated, [.enumeration(1), .number(1.5), .numbers([10, 20])])
        check(ViewContract.pointerEntered)
        check(ViewContract.pointerExited)
        check(ViewContract.pointerMoved, [.numbers([1, 2])])
        check(ViewContract.pointerPressed, [.numbers([1, 2])])
        check(ViewContract.pointerReleased, [])
        check(ViewContract.swiped, [.enumeration(1)])
        check(KeyboardElementContract.keyPressed, [Key.escape.propValue, KeyModifiers.shift.propValue])
        check(VisualElementContract.accessibilityActionPerformed, [.string("Clear")])
        check(VisualElementContract.accessibilityAdjusted, [AccessibilityAdjustment.decrement.propValue])
        check(ViewContract.tapped)
        check(ViewContract.held)
        check(TextInputContract.textChanged, [.string("typed")])
        check(ActionElementContract.clicked)

        // The elements.
        check(ButtonContract.clicked)
        check(ButtonContract.pressed)
        check(ButtonContract.released)
        check(CanvasContract.dragged, [.numbers([1, 2])])
        check(CanvasContract.pressed, [.numbers([1, 2])])
        check(CanvasContract.released, [.numbers([1, 2])])
        check(CheckBoxContract.toggled, [.bool(true)])
        check(DatePickerContract.closed)
        check(DatePickerContract.dateChanged, [.numbers([2026, 9, 15])])
        check(DatePickerContract.opened)
        check(ItemsViewContract.endReached)
        check(ItemsViewContract.itemActivated, [.string("7")])
        check(ItemsViewContract.realizedChanged, [.strings(["3", "4"])])
        check(ItemsViewContract.selectedItemsChanged, [.strings(["7"])])
        check(LinkContract.clicked)
        check(MapContract.mapClicked, [.numbers([52.25, 21.01])])
        check(NavigationStackContract.popped, [.number(1)])
        check(PageContract.appearing)
        check(PageContract.disappearing)
        check(PageContract.navigatedFrom)
        check(PageContract.navigatedTo)
        check(PageContract.navigatingFrom)
        check(PickerContract.closed)
        check(PickerContract.opened)
        check(PickerContract.selectedIndexChanged, [.number(-1)])
        check(MarkerContract.selected)
        check(MenuToggleContract.toggled, [.bool(true)])
        check(ToolbarToggleContract.toggled, [.bool(true)])
        check(MarkerContract.detailsClicked)
        check(SheetContract.isPresentedChanged, [.bool(false)])
        check(PopoverContract.isPresentedChanged, [.bool(false)])
        check(RefreshElementContract.refreshRequested)
        check(SceneContract.activated)
        check(SceneContract.deactivated)
        check(SceneContract.stopped)
        check(SceneContract.windowClosed, [.string("2")])
        check(ScrollViewContract.scrollStopped)
        check(SearchFieldContract.submitted)
        check(SliderContract.released)
        check(SliderContract.pressed)
        check(SliderContract.valueChanged, [.number(0.5)])
        check(SplitViewContract.showsSidebarChanged, [.bool(false)])
        check(StepperContract.valueChanged, [.number(3)])
        check(SwitchContract.toggled, [.bool(true)])
        check(TabViewContract.selectedTabChanged, [.number(1)])
        check(TextFieldContract.submitted)
        check(TimePickerContract.closed)
        check(TimePickerContract.opened)
        check(TimePickerContract.timeChanged, [.numbers([9, 30, 0])])
        check(WebViewContract.canGoBackChanged, [.bool(true)])
        check(WebViewContract.canGoForwardChanged, [.bool(false)])
        check(WebViewContract.navigated, [.enumeration(1), .enumeration(3), address])
        check(WebViewContract.navigating, [.enumeration(3), address])
        check(WebViewContract.processTerminated)
        check(WindowContract.activated)
        check(WindowContract.created)
        check(WindowContract.deactivated)
        check(WindowContract.destroying)
        check(WindowContract.linkOpened, [.string("notes://note/7")])
        check(WindowContract.resumed)
        check(WindowContract.stopped)

        var events: Set<String> = []

        for contract in LibraryContracts.all {
            for member in contract.members where (member as? any DeclaredMember)?.facts.kind == .event {
                events.insert("\(contract.name).\(member.name)")
            }
        }

        XCTAssertEqual(events.subtracting(checked).sorted(), [], "an event member with no payload in this table")
        XCTAssertEqual(checked.subtracting(events).sorted(), [], "a payload for no event member")
    }

    // MARK: - Support

    /// An event that carries nothing, and the nothing it carries.
    private func check<Owner: Contract>(
        _ event: ElementEvent<Owner, Void>,
        _ payload: [PropValue] = [],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        checked.insert("\(Owner.name).\(event.name)")
        XCTAssertTrue(payload.isEmpty, "\(Owner.name).\(event.name) carries nothing", file: file, line: line)
    }

    /// An event that carries one value.
    private func check<Owner: Contract, Value: HostRepresentable>(
        _ event: ElementEvent<Owner, Value>,
        _ payload: [PropValue],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        checked.insert("\(Owner.name).\(event.name)")
        XCTAssertNotNil(
            MemberValues.decode(payload, as: Value.self),
            "\(Owner.name).\(event.name) refuses \(payload)", file: file, line: line)
    }

    /// An event that carries two values.
    private func check<Owner: Contract, First: HostRepresentable, Second: HostRepresentable>(
        _ event: ElementEvent<Owner, (First, Second)>,
        _ payload: [PropValue],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        checked.insert("\(Owner.name).\(event.name)")
        XCTAssertNotNil(
            MemberValues.decode(payload, as: First.self, Second.self),
            "\(Owner.name).\(event.name) refuses \(payload)", file: file, line: line)
    }

    /// An event that carries three values.
    private func check<Owner: Contract, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable>(
        _ event: ElementEvent<Owner, (First, Second, Third)>,
        _ payload: [PropValue],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        checked.insert("\(Owner.name).\(event.name)")
        XCTAssertNotNil(
            MemberValues.decode(payload, as: First.self, Second.self, Third.self),
            "\(Owner.name).\(event.name) refuses \(payload)", file: file, line: line)
    }
    /// An event that carries four values.
    private func check<
        Owner: Contract, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable,
        Fourth: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third, Fourth)>,
        _ payload: [PropValue],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        checked.insert("\(Owner.name).\(event.name)")
        XCTAssertNotNil(
            MemberValues.decode(payload, as: First.self, Second.self, Third.self, Fourth.self),
            "\(Owner.name).\(event.name) refuses \(payload)", file: file, line: line)
    }
}
