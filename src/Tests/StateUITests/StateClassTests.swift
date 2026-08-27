// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A class that reports its own writes.
//
// `@State` covers a value: the write goes through the box, and the box asks for
// a render. A class is the case it cannot cover, the box holding a reference
// that nothing writes THROUGH - so these check the other half, that a property
// on a `@StateClass` class says the same thing a `@State` does.
//
// The macro is not expanded here on purpose. What an author cares about is that
// a write reaches the renderer, that an `@Untracked` one does not, and that
// building an object is not a change to the interface. Every shape the macro has
// to survive is in the models below - a `let`, a computed property, a `static`,
// a `weak` one, a property with no default assigned in `init` - so this file
// compiling is a test in its own right.

import Observation
import StateUIWireProbe
import XCTest
@testable import StateUI

@StateClass
private final class Cart {
    var items: [String] = []
    var note: String

    /// Never written after init, so there is nothing to report.
    let created = "once"

    /// Written on every save; nothing on screen shows it.
    @Untracked var lastSaved = ""

    /// Computed from a tracked property, so it follows without being one.
    var isEmpty: Bool { items.isEmpty }

    /// The type's own value, not this instance's - and `nonisolated(unsafe)`
    /// because Swift 6 asks for it on any mutable static, macro or no macro.
    nonisolated(unsafe) static var currency = "PLN"

    init(note: String = "") {
        self.note = note
    }
}

/// A model of the kind another package ships: Swift's own `@Observable`,
/// which reports its writes to an observation scope rather than to this
/// library. Held here so the tests can measure that difference.
@Observable
private final class ForeignCart {
    var note = ""
}

@StateClass
private final class CartLine {
    var title = ""

    /// Holds its cart without keeping it alive - which only works if the macro
    /// left `weak` on the storage it wrote.
    weak var cart: Cart?
}

/// A view that keeps a model rather than a value.
private struct CartPage: ContentView {
    @State var cart = Cart()

    var content: Element {
        Button("Items: \(cart.items.count)").onClicked { cart.items.append("one") }
    }
}

/// A view that OWNS the model, so `$cart` is already a binding to it.
private struct CartOwner {
    @State var cart = Cart()

    /// What `Entry($cart.note)` would be given.
    var note: Binding<String> { $cart.note }
}

/// A view that was LENT the model. There is no second wrapper for a class: a
/// model is borrowed with `@Binding`, exactly as an Int is.
private struct NoteRow {
    @Binding var basket: Cart

    var note: Binding<String> { $basket.note }
}

final class StateClassTests: XCTestCase {
    override func setUp() {
        super.setUp()
        settled()
    }

    func testWritingATrackedPropertyAsksForAnotherRender() {
        let cart = Cart()
        settled()

        cart.note = "for later"

        XCTAssertTrue(Renderer.shared.needsRender,
                      "a write to a property of the model is a write the renderer hears about")
    }

    func testWritingAnUntrackedPropertyAsksForNothing() {
        let cart = Cart()
        settled()

        cart.lastSaved = "12:00"

        XCTAssertFalse(Renderer.shared.needsRender,
                       "@Untracked is the opt-out, and nothing on screen shows this")
    }

    func testMutatingAPropertyInPlaceIsAWriteLikeAnyOther() {
        let cart = Cart()
        settled()

        cart.items.append("Something")

        XCTAssertEqual(cart.items, ["Something"])
        XCTAssertFalse(cart.isEmpty, "and the computed property follows the tracked one")
        XCTAssertTrue(Renderer.shared.needsRender)
    }

    func testBuildingAModelIsNotAChangeToTheInterface() {
        settled()

        let cart = Cart(note: "assigned in init")

        XCTAssertEqual(cart.note, "assigned in init")
        XCTAssertFalse(Renderer.shared.needsRender, """
            An object being built is not an interface changing. This is what the \
            generated `init` accessor is for: without it the assignment in `init` \
            would go through the SETTER - which Swift refuses before `self` is \
            fully initialized, and which would ask for a render nobody needs.
            """)
    }

    func testAClassTheMacroTouchedSaysSo() {
        // Compiling is the test. Nothing in Cart's declaration says
        // `: StateClass` - the macro adds it - and that conformance is what
        // `Bindable` asks for before it will lend a property.
        let reported: any StateClass = Cart()

        XCTAssertNotNil(reported)
    }

    func testAWeakPropertyIsStillWeak() {
        let line = CartLine()
        holdBriefly(in: line)

        XCTAssertNil(line.cart, """
            The storage the macro wrote kept `weak`, so the line never held the \
            cart up. Access control does not travel the same way - the storage is \
            always private - but the reference strength describes the storage \
            itself and has to.
            """)
    }

    func testAModelInStateSurvivesTheRebuildAndReportsItsWrites() {
        let renders = Renders()

        let first = renders.render(CartPage().body)
        settled()

        renders.fire(first.events?["clicked"] ?? -1)

        XCTAssertTrue(Renderer.shared.needsRender,
                      "the handler wrote a property of the model, which is a render")

        // A fresh view, as every render makes one - and a fresh `Cart()` with
        // it, which the box throws away in favour of the one it is holding.
        let second = renders.render(CartPage().body)

        XCTAssertEqual(second.props["text"], .string("Items: 1"),
                       "the model the box kept is the one the rebuilt view reads")
    }

    func testABindingReachesOnePropertyOfTheModelItOwns() {
        let owner = CartOwner()
        settled()

        let note = owner.note

        XCTAssertEqual(note.wrappedValue, "", "it reads the property, not the model")

        note.wrappedValue = "for later"

        XCTAssertEqual(owner.cart.note, "for later",
                       "and writes it where the model keeps it")
        XCTAssertTrue(Renderer.shared.needsRender)
    }

    func testAModelIsLentTheWayAnyOtherValueIs() {
        let owner = CartOwner()
        let row = NoteRow(basket: owner.$cart)
        settled()

        row.note.wrappedValue = "written through the child"

        XCTAssertEqual(owner.cart.note, "written through the child", """
            `$cart` lends the model; `$basket.note` inside the child lends one \
            property of it onwards. One wrapper for both, because a model is a \
            value like any other as far as borrowing is concerned.
            """)
        XCTAssertTrue(Renderer.shared.needsRender)
    }

    func testLendingAModelLendsTheWholeOfIt() {
        let owner = CartOwner()
        let row = NoteRow(basket: owner.$cart)
        let replacement = Cart(note: "a different cart")
        settled()

        row.basket = replacement

        XCTAssertTrue(owner.cart === replacement, """
            `$` says: I lend you this, do with it what you want - which includes \
            replacing it. A parent meaning to lend less hands the object itself \
            and the child builds its own Binding(get:set:).
            """)
        XCTAssertTrue(Renderer.shared.needsRender)
    }

    // MARK: - Support

    /// Points the line at a cart that goes out of scope when this returns.
    ///
    /// A local in a function is what makes the release deterministic; the same
    /// thing written inline in the test would be at the mercy of when the
    /// enclosing scope ends.
    private func holdBriefly(in line: CartLine) {
        let cart = Cart()
        line.cart = cart

        XCTAssertNotNil(line.cart, "held while the cart is alive")
    }

    func testAnObservableWriteAsksForNothing() {
        let cart = ForeignCart()
        settled()

        cart.note = "for later"

        XCTAssertFalse(Renderer.shared.needsRender, """
            The write reaches the object and nobody else. `@Observable` \
            notifies whoever armed an observation scope around the read, and \
            nothing here arms one - so the interface would go on showing the \
            old value with nothing failing anywhere. That silence is what the \
            deprecation in Core/Observable.swift names at the declaration, \
            and this is the measurement it stands on.
            """)
    }

    func testHoldingAnObservableModelIsSaidAtTheDeclaration() throws {
        let refusals = try Fixtures.allSources()
            .first { $0.path.hasSuffix("Core/Observable.swift") }

        let text = try XCTUnwrap(refusals?.text, "Core/Observable.swift is where this is said")

        let declared = text.components(separatedBy: "public convenience init").count - 1
        let deprecated = text.components(separatedBy: "@available(*, deprecated").count - 1

        XCTAssertEqual(declared, 2, "both ways of writing one - @State and file scope")
        XCTAssertEqual(deprecated, declared, """
            Every initializer there exists to carry the sentence. One left \
            without it takes an @Observable model silently, which is the whole \
            thing this file is for.
            """)
    }

    /// Renders once, so that `needsRender` says something about what the test
    /// does next rather than about whatever ran before it.
    private func settled() {
        _ = WireProbe.decodeMessage(Renderer.shared.renderWire(baseline: 0))
        XCTAssertFalse(Renderer.shared.needsRender)
    }
}
