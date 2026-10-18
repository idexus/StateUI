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

    /// A VIEW HELD AS AN EXISTENTIAL is walked as its own type, its path naming it.
    func testAViewHeldAsAnExistentialIsWalkedAsItsOwnType() {
        let said = said(Header(header: Text("Notes")))

        XCTAssertEqual(said.first, " parts 1")
        XCTAssertTrue(said.contains { $0.hasPrefix(".header(Swift.Optional<StateUI.View>).some(StateUI.Text)") }, "\(said)")
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

    /// A STATE IS FOUND UNDER ITS PROPERTY'S BACKING NAME, a box to pair with its predecessor's.
    func testAStateIsFoundUnderItsBackingName() {
        let parts = stateParts(in: Counter())

        XCTAssertEqual(parts.boxes.count, 1)
        XCTAssertTrue(parts.boxes[0].path.hasPrefix("._count"), parts.boxes[0].path)
    }
}
