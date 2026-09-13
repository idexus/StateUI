// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// State declared INSIDE A CLASS: `final class Cart { @State var note = "" }`.
//
// The same wrapper a view uses, on a model's properties - so a write to `note`
// says exactly what a write to a view's `@State` says, about exactly one
// property; a read at build records that property; the model's own `$note` is
// the whole state, handed to the host as a field's text or a driven value; and
// `debugInfo()` names the property, which is the one thing a wrapper in a
// class cannot know by itself (Core/State.swift, the enclosing-instance road).
//
// A plain `var` on the same class is stored and nothing more, and writing it
// asks for nothing.

import Observation
import StateUIWireProbe
import XCTest
@_spi(Host) @testable import StateUI

private final class Cart {
    @State var items: [String] = []
    @State var note = ""

    /// A value the host walks - a model's state has a journey as a view's has.
    @State var fade = 1.0

    /// Never written after init, so there is nothing to report.
    let created = "once"

    /// Written on every save; nothing on screen shows it. A plain `var`,
    /// stored and nothing more.
    var lastSaved = ""

    /// Computed from a state, so it follows without being one.
    var isEmpty: Bool { items.isEmpty }

    /// The type's own value, not this instance's - and `nonisolated(unsafe)`
    /// because Swift 6 asks for it on any mutable static.
    nonisolated(unsafe) static var currency = "PLN"

    /// A model's property has a DEFAULT, and an initializer writes over it:
    /// the write goes through the setter, to a state nobody reads yet, and
    /// asks for nothing. (A wrapped property with no default cannot be
    /// assigned in `init` at all - `State.init(wrappedValue:)` is an
    /// autoclosure, so the initial value costs once - and the compiler says
    /// so.)
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

/// A view that keeps a model rather than a value.
private struct CartPage: ContentView {
    @State var cart = Cart()

    var content: any View {
        Button("Items: \(cart.items.count)").onClicked { cart.items.append("one") }
    }
}

/// A view that OWNS the model, so `$cart` is already a binding to it.
private struct CartOwner {
    @State var cart = Cart()

    /// What `Entry($cart.note)` would be given - a binding INTO the model,
    /// through a key path.
    var note: Binding<String> { $cart.note }
}

/// A view that was LENT the model. There is no second wrapper for a class: a
/// model is borrowed with `@Binding`, exactly as an Int is.
private struct NoteRow {
    @Binding var basket: Cart

    var note: Binding<String> { $basket.note }
}

/// How many times a closure was built, and what `debugInfo()` said there - a
/// class, so a closure the view keeps can write into it.
private final class Tally {
    var builds = 0
    var said = ""
}

/// A view whose content is one read the test chooses, so what it rebuilds
/// for is exactly what the closure read - and which hands the closure the
/// reading, because `debugInfo()` answers about the build that is RUNNING.
private struct Reader: ContentView {
    let read: (String) -> Void

    init(_ read: @escaping (String) -> Void) {
        self.read = read
    }

    var content: any View {
        read(debugInfo())
        return Label("reader")
    }
}

final class ModelStateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        settled()
    }

    func testWritingAModelsStateAsksForAnotherRender() {
        let cart = Cart()
        let reader = reading { _ = cart.note }
        settled()

        cart.note = "for later"

        XCTAssertTrue(Renderer.shared.needsRender,
                      "a write to a property of the model is a write the renderer hears about")
        _ = reader
    }

    /// A WRITE TO ONE PROPERTY IS ABOUT THAT PROPERTY, not about the object:
    /// a closure reading `items` is no reader of `note`, so a write to `note`
    /// has nobody to rebuild and asks for nothing - the same refusal a `@State`
    /// nobody reads gets.
    func testAWriteToAPropertyNobodyReadsAsksForNothingThoughAnotherIsRead() {
        let cart = Cart()
        let reader = reading { _ = cart.items }
        defer { _ = reader }
        settled()

        cart.note = "for later"

        XCTAssertFalse(Renderer.shared.needsRender, """
            The one live closure reads `items`. A write to `note` is a write \
            to a property nobody on screen shows, and the renderer refuses it \
            exactly as it refuses a write to a `@State` nobody reads.
            """)

        cart.items.append("Something")

        XCTAssertTrue(Renderer.shared.needsRender,
                      "and a write to the property it DOES read is heard")
    }

    /// The same promise seen from the walk: two closures over one model, one
    /// reading `items` and one reading `note`, and a write to `note` rebuilds
    /// the second alone - AND EACH SAYS WHICH PROPERTY IT WAS BUILT FOR. The
    /// name is the half a wrapper in a class cannot know on its own: without
    /// the enclosing-instance road in Core/State.swift both readings said
    /// `for Storage`, measured before it was written.
    func testAWriteToOnePropertyRebuildsOnlyItsReadersAndNamesIt() {
        let cart = Cart()
        let items = Tally()
        let note = Tally()
        let renders = Renders()

        renders.render(stack([
            Reader { items.builds += 1; _ = cart.items; items.said = $0 }.body,
            Reader { note.builds += 1; _ = cart.note; note.said = $0 }.body,
        ], id: "root"))
        settled()
        XCTAssertEqual(items.builds, 1)
        XCTAssertEqual(note.builds, 1)

        cart.note = "for later"
        _ = renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(items.builds, 1, "the closure reading `items` was not built again")
        XCTAssertEqual(note.builds, 2, "the one reading `note` was")
        XCTAssertEqual(note.said, "Reader: 2 builds, for note",
                       "and it says so by the property's own name")

        // And the other way round, so the test is not about which came first.
        // The renderer's changed set is taken by a render and not by a test's
        // revisit, so it is cleared by hand between the two rounds.
        Renderer.shared.clearInvalidation()
        cart.items.append("Something")
        _ = renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(items.builds, 2)
        XCTAssertEqual(note.builds, 2)
        XCTAssertEqual(items.said, "Reader: 2 builds, for items")
    }

    /// THE MODEL'S OWN `$note` IS THE WHOLE STATE, and a field handed it is no
    /// reader of it: the host carries the text, the typed words land on the
    /// model, and nobody renders for a value nobody prints - exactly what
    /// `Entry($name)` over a view's `@State` does.
    func testAModelsOwnStateIsHandedToTheHostWhole() {
        let cart = Cart()
        let holder = Tally()
        let renders = Renders()

        XCTAssertNotNil(cart.$note.image, "`cart.$note` has a storage, so the host carries it")
        XCTAssertNotNil(cart.$note.followed, "and an engine can follow it")

        renders.render(stack([
            Reader { _ in holder.builds += 1; _ = Entry(cart.$note) }.body,
        ], id: "root"))
        settled()
        XCTAssertEqual(holder.builds, 1)

        typed(Renderer.shared.number(for: cart.$note.image!), "Ada")

        XCTAssertEqual(cart.note, "Ada", "the typed words landed on the model")
        XCTAssertFalse(Renderer.shared.needsRender, "and nobody read it, so nobody renders")

        cart.note = "Grace"

        XCTAssertFalse(Renderer.shared.needsRender,
                       "a write from this side finds the same: the field's closure is no reader")
        XCTAssertEqual(holder.builds, 1)
    }

    /// A walked state in a model is walked by the host as one in a view is: a
    /// driven modifier takes `cart.$fade`, the journey is `cart.$fade.journey`,
    /// and the value moving renders nobody.
    func testAJourneyInAModelIsWalkedByTheHost() {
        let cart = Cart()
        let holder = Tally()
        let renders = Renders()

        XCTAssertNotNil(cart.$fade.journeyImage, "a walked state in a model has an image the host walks")
        XCTAssertEqual(cart.$fade.journey.value, 1, "and a journey to read")

        renders.render(stack([
            Reader { _ in holder.builds += 1; _ = BoxView().opacity(cart.$fade) }.body,
        ], id: "root"))
        settled()

        cart.fade = 0.2

        XCTAssertFalse(Renderer.shared.needsRender, "a driven value moving is nobody's reason to render")
        XCTAssertEqual(holder.builds, 1)
    }

    /// `$cart.note` - the model's property reached THROUGH the holding state
    /// by a key path - is a PART of that state, with no storage of its own:
    /// it takes the described road, as `$room.width` does.
    func testAKeyPathBindingIntoAModelIsDescribed() {
        let owner = CartOwner()

        XCTAssertNil(owner.note.image, "a key-path binding has no storage of its own")
        XCTAssertNotNil(owner.cart.$note.image, "the model's own `$note` is the whole state")
    }

    /// ONE MODEL, ANY NUMBER OF VIEWS - a page and a row, a badge and an
    /// editor, a window and a page. The model is one object, so its states are
    /// one each: every view that reads `note` is a reader of that one state
    /// and a write reaches them all, a view that only hands `cart.$note` on is
    /// no reader at all, and the words the host types land on the one storage
    /// every reader was built from - whichever of them touched the model
    /// first, since the first touch is what names it.
    func testTwoViewsOverOneModelMeetTheSameStates() {
        let cart = Cart()
        let page = Tally()
        let row = Tally()
        let field = Tally()
        let renders = Renders()

        renders.render(stack([
            Reader { page.builds += 1; _ = cart.note; page.said = $0 }.body,
            Reader { _ in field.builds += 1; _ = Entry(cart.$note) }.body,
            Reader { row.builds += 1; _ = cart.note; row.said = $0 }.body,
        ], id: "root"))
        settled()

        cart.note = "for later"
        _ = renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(page.builds, 2, "the page reads `note`")
        XCTAssertEqual(row.builds, 2, "and so does the row")
        XCTAssertEqual(field.builds, 1, "the view that only hands the state on is no reader")
        XCTAssertEqual(page.said, "Reader: 2 builds, for note")
        XCTAssertEqual(row.said, "Reader: 2 builds, for note")

        // Typed on the host: one storage, so both readers hear it and the
        // field's closure still does not.
        Renderer.shared.clearInvalidation()
        typed(Renderer.shared.number(for: cart.$note.image!), "Ada")

        XCTAssertEqual(cart.note, "Ada")
        XCTAssertTrue(Renderer.shared.needsRender, "two readers show the note")
        _ = renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(page.builds, 3)
        XCTAssertEqual(row.builds, 3)
        XCTAssertEqual(field.builds, 1)
    }

    /// `Entry(cart.$note)` written in a closure over `@State var cart` reads
    /// the BOX holding the reference and not `note`: a write to `note` leaves
    /// the closure standing, and REPLACING the model rebuilds it - which is
    /// when the field has to be handed the new model's state, or it would go
    /// on showing the old one's.
    func testHandingAModelsStateOnReadsTheModelsBoxAndNotTheProperty() {
        let owner = CartOwner()
        let holder = Tally()
        let renders = Renders()

        renders.render(stack([
            Reader { _ in holder.builds += 1; _ = Entry(owner.cart.$note) }.body,
        ], id: "root"))
        settled()
        XCTAssertEqual(holder.builds, 1)

        owner.cart.note = "for later"

        XCTAssertFalse(Renderer.shared.needsRender, "a write to `note` reaches no reader of the box")

        owner.cart = Cart(note: "a different cart")

        XCTAssertTrue(Renderer.shared.needsRender, "replacing the model reaches the closure that handed its state on")
        _ = renders.revisit(changed: Renderer.shared.pendingChanges)
        XCTAssertEqual(holder.builds, 2)
    }

    /// Two instances of one class are two sets of states, as two views'
    /// `@State`s are: a write to one cart's `note` is nobody's reason to
    /// rebuild a reader of the other's.
    func testTwoModelsOfOneClassAreTwoSetsOfStates() {
        let mine = Cart()
        let yours = Cart()
        let reader = reading { _ = mine.note }
        defer { _ = reader }
        settled()

        yours.note = "not yours to draw"

        XCTAssertFalse(Renderer.shared.needsRender, "the live closure reads the other cart")

        mine.note = "mine"

        XCTAssertTrue(Renderer.shared.needsRender)
    }

    /// A model NO live element reads asks for nothing when written - the same
    /// rule as a `@State`, each property being one.
    func testWritingAModelNobodyReadsAsksForNothing() {
        let cart = Cart()
        settled()

        cart.note = "for later"

        XCTAssertFalse(Renderer.shared.needsRender, "nothing on screen reads it")
    }

    func testWritingAPlainPropertyAsksForNothing() {
        let cart = Cart()
        let reader = reading { _ = cart.lastSaved }
        defer { _ = reader }
        settled()

        cart.lastSaved = "12:00"

        XCTAssertFalse(Renderer.shared.needsRender,
                       "a plain `var` is stored and nothing more, read or not")
    }

    /// AND A PLAIN `var` IS CARRIED ALONG BY A REBUILD IT DID NOT CAUSE, which
    /// is what makes one look as though it worked now and then: a closure that
    /// reads a `@State` property BESIDE it is rebuilt when THAT moves, and the
    /// plain value is read afresh on the way through. So the screen catches up
    /// at the next unrelated write and never at its own.
    func testAPlainPropertyIsCarriedAlongByARebuildSomethingElseCaused() {
        let cart = Cart()
        let shown = Tally()
        let renders = Renders()

        renders.render(stack([
            Reader { _ in shown.builds += 1; shown.said = "\(cart.note)/\(cart.lastSaved)" }.body,
        ], id: "root"))
        settled()
        XCTAssertEqual(shown.said, "/")

        cart.lastSaved = "12:00"
        _ = renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(shown.builds, 1, "its own write reaches nobody")
        XCTAssertEqual(shown.said, "/", "so the screen still says what it said")

        Renderer.shared.clearInvalidation()
        cart.note = "for later"
        _ = renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(shown.builds, 2)
        XCTAssertEqual(shown.said, "for later/12:00", """
            The write to `note` rebuilt the closure, and the plain value was \
            read again on the way - which is how a property nothing tracks \
            appears on screen late, at somebody else's write.
            """)
    }

    func testMutatingAPropertyInPlaceIsAWriteLikeAnyOther() {
        let cart = Cart()
        let reader = reading { _ = cart.items }
        settled()

        cart.items.append("Something")

        XCTAssertEqual(cart.items, ["Something"])
        XCTAssertFalse(cart.isEmpty, "and the computed property follows the state")
        XCTAssertTrue(Renderer.shared.needsRender)
        _ = reader
    }

    func testBuildingAModelIsNotAChangeToTheInterface() {
        settled()

        let cart = Cart(note: "assigned in init")

        XCTAssertEqual(cart.note, "assigned in init")
        XCTAssertFalse(Renderer.shared.needsRender, """
            An object being built is not an interface changing: the write in \
            `init` goes to a state nobody has read, and is refused as any such \
            write is.
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
        let second = renders.render(CartPage().body, changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(second.props["text"], .string("Items: 1"),
                       "the model the box kept is the one the rebuilt view reads")
    }

    func testABindingReachesOnePropertyOfTheModelItOwns() {
        let owner = CartOwner()
        let reader = reading { _ = owner.cart.note }
        defer { _ = reader }
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
        let reader = reading { _ = owner.cart.note }
        defer { _ = reader }
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
        let reader = reading { _ = owner.cart.note }
        defer { _ = reader }
        settled()

        row.basket = replacement

        XCTAssertTrue(owner.cart === replacement, """
            `$` says: I lend you this, do with it what you want - which includes \
            replacing it. A parent meaning to lend less hands the object itself \
            and the child builds its own Binding(get:set:).
            """)
        XCTAssertTrue(Renderer.shared.needsRender)
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
