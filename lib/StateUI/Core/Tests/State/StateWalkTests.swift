// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@testable import StateUI

/// A value compared whole.
private struct Icon: Equatable {
    let name: String
    let glyph: Int
}

/// A view of plain fields.
private struct Tile: View {
    let icon: Icon
    let lifted: Bool

    var body: some View { Text(icon.name) }
}

/// A view holding another view as an existential, which a mirror hands back wrapped.
private struct Header: View {
    let header: (any View)?

    var body: some View { Text("header") }
}

/// An object a view may hold.
private final class Model {}

/// A view holding a reference weakly and a closure: only a mirror reads it.
private struct Holder: View {
    weak var model: Model?
    let action: () -> Void

    var body: some View { Text("holder") }
}

/// A view naming its parts to the walk, one of its two.
private struct Named: View, WalkedView {
    let shown: Int
    let unsaid: Int

    var body: some View { Text("named") }
    var walkedParts: [(label: String, value: Any)] { [("shown", shown)] }
}

/// A view lent a binding, or none.
private struct Lent: View {
    let value: Binding<Double>?

    var body: some View { Text("lent") }
}

/// A view owning a state.
private struct Counter: View {
    @State var count = 0

    var body: some View { Text("\(count)") }
}

/// A view owning a state, compared by its author's own equality.
private struct LabelledCounter: View, @MainActor Equatable {
    @State var count = 0
    let label: String

    var body: some View { Text("\(label) \(count)") }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.label == rhs.label }
}

/// The walk over a view's stored properties: what it finds and under which paths, the same however the type is read.
@MainActor
final class StateWalkTests: XCTestCase {
    /// The walk's inputs as words: each path and what it is compared as.
    private func said(_ view: Any) -> [String] {
        stateParts(in: view).inputs.map { path, input in
            let kind = switch input {
            case .value: "value"
            case .reference: "reference"
            case .borrowed: "borrowed"
            case .box: "box"
            case .slot: "slot"
            case .parts(let count): "parts \(count)"
            case .opaque: "opaque"
            }
            return "\(path) \(kind)"
        }
    }

    /// A VIEW OF PLAIN FIELDS is its fields, each compared whole - the first walk and every one after.
    func testAViewOfPlainFieldsIsItsFields() {
        for _ in 0..<2 {
            XCTAssertEqual(said(Tile(icon: Icon(name: "Mail", glyph: 1), lifted: true)), [
                " parts 2", ".icon value", ".lifted value",
            ])
        }
    }

    /// A VIEW HELD AS AN EXISTENTIAL is walked as its own type, its path naming it - the same path whatever value of
    /// its optional the process met first.
    func testAViewHeldAsAnExistentialIsWalkedAsItsOwnType() {
        _ = said(Header(header: nil))
        let said = said(Header(header: Text("Notes")))

        XCTAssertEqual(said.first, " parts 1")
        XCTAssertTrue(said.contains { $0.hasPrefix(".header.some(StateUI.Text) ") }, "\(said)")
    }

    /// A REFERENCE HELD WEAKLY AND A CLOSURE are read as a mirror reads them: the object as itself, the closure as
    /// what nothing compares.
    func testAWeakReferenceAndAClosureAreReadAsAMirrorReadsThem() {
        let model = Model()
        let said = said(Holder(model: model, action: {}))

        XCTAssertEqual(said.first, " parts 2")
        XCTAssertTrue(said.contains(".model.some reference"), "\(said)")
        XCTAssertTrue(said.contains(".action opaque"), "\(said)")
    }

    /// AN OPTIONAL IS WHAT IT HOLDS, value by value: a binding where it holds one, nothing where it holds none - in
    /// either order.
    func testAnOptionalIsWhatItHoldsValueByValue() {
        let level = State(wrappedValue: 1.0)
        let some = Lent(value: level.projectedValue)
        let none = Lent(value: nil)

        XCTAssertEqual(said(some), [" parts 1", ".value borrowed"])
        XCTAssertEqual(said(none), [" parts 1", ".value parts 0"])
        XCTAssertEqual(said(some), [" parts 1", ".value borrowed"])
    }

    /// AN ITEMSVIEW'S ENTRY IS ONE VALUE to the walk: what it shows and where from, compared whole with no mirror -
    /// every entry the list keeps is walked at each of its renders.
    func testAnItemsViewsEntryIsOneValue() {
        let source = ItemsSource<Int>(groups: [], grouped: false)
        XCTAssertEqual(said(ItemsEntry(identity: "7", source: source)), [" value"])
    }

    /// A VIEW NAMING ITS PARTS IS WALKED BY THEM, with no mirror: a layout's holder, generic over its view, at every
    /// item of every render.
    func testAViewNamingItsPartsIsWalkedByThem() {
        XCTAssertEqual(said(Named(shown: 1, unsaid: 2)), [" parts 1", ".shown value"])
        XCTAssertEqual(said(LayoutItemView(content: Text("7"))).prefix(2), [" parts 1", ".content(StateUI.Text) parts 1"])
    }

    /// A VIEW LYING BYTE FOR BYTE AS ITS PREDECESSOR TAKES ITS WALK, with no mirror made: the same values, the same
    /// storage. Another value, an owned state's fresh box, or a closure - which counts as changed whatever its
    /// bytes - is walked.
    func testAViewLyingAsItsPredecessorTakesItsWalk() {
        let icon = Icon(name: "Mail", glyph: 1)
        let kept = ViewWalk(Tile(icon: icon, lifted: false))
        _ = kept.parts

        XCTAssertTrue(ViewWalk(Tile(icon: icon, lifted: false)).takes(kept), "the same icon, not lifted")
        XCTAssertFalse(ViewWalk(Tile(icon: icon, lifted: true)).takes(kept), "lifted")
        XCTAssertFalse(ViewWalk(Counter()).takes(ViewWalk(Counter())), "a state's box of its own")
        let action = {}
        let held = ViewWalk(Holder(model: nil, action: action))
        XCTAssertFalse(ViewWalk(Holder(model: nil, action: action)).takes(held), "a closure")
    }

    /// AN EQUATABLE VIEW OWNING A STATE IS LOOKED INTO: its author's equality cannot pair its state with its
    /// predecessor's, so the walk reads it part by part; one holding no state is compared whole.
    func testAnEquatableViewOwningAStateIsLookedInto() {
        let parts = stateParts(in: LabelledCounter(label: "Taps"))

        XCTAssertEqual(parts.boxes.count, 1)
        XCTAssertTrue(parts.boxes.first?.path.hasPrefix("._count") == true, "\(parts.boxes)")
        XCTAssertEqual(said(Icon(name: "Mail", glyph: 1)), [" value"])
    }

    /// A STATE IS FOUND UNDER ITS PROPERTY'S BACKING NAME, a box to pair with its predecessor's.
    func testAStateIsFoundUnderItsBackingName() {
        let parts = stateParts(in: Counter())

        XCTAssertEqual(parts.boxes.count, 1)
        XCTAssertTrue(parts.boxes[0].path.hasPrefix("._count"), parts.boxes[0].path)
    }
}
