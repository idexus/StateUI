// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a row LOOKS like, and who is allowed to stand in for whom.
//
// The number itself is nobody's business - these read it only by comparing two
// of them - but WHICH rows share one is the whole contract: a control the host
// hands to another row is given a value for every property it already carries,
// so two rows may share a shape exactly when they name the same properties on
// the same controls in the same places.

import XCTest

@testable import StateUI

final class RecyclingTests: XCTestCase {
    /// The rows of a layout that recycles, as they crossed.
    private func rows(_ patch: Patch) -> [Patch] {
        patch.children.first { $0.type == .absoluteLayout }?.children ?? []
    }

    /// A layout of rows, each written by one template from its number.
    private func run(_ numbers: [Int], _ row: @escaping (Int) -> Element) -> Node {
        VStack {
            AbsoluteLayout {
                ForEach(numbers, id: \.self) { number in
                    row(number)
                }
            }
            .recycling()
        }
        .body
    }

    // MARK: - What a shape is

    func testTwoRowsWrittenByOneTemplateShareAShape() {
        let renders = Renders()
        let patch = renders.render(run([1, 2, 3]) { number in
            HStack {
                Label("\(number)").fontSize(13)
                Label("\(number * number)")
            }
        })

        let shapes = rows(patch).map { $0.shape }

        XCTAssertEqual(shapes.count, 3)
        XCTAssertNotEqual(shapes[0], Recycling.none, "an ordinary row of labels is poolable")
        XCTAssertEqual(Set(shapes).count, 1,
                       "the same template wrote all three, so all three look alike")
    }

    func testAConditionalModifierSplitsTheShape() {
        let renders = Renders()
        let patch = renders.render(run([1, 2, 3]) { number in
            // The second row alone is coloured, so the second row alone names
            // `textColor` - and a control that never had one must not be
            // handed to it.
            var label = Label("\(number)").fontSize(13)
            if number == 2 { label = label.textColor(.red) }
            return HStack { label }
        })

        let shapes = rows(patch).map { $0.shape }

        XCTAssertEqual(shapes[0], shapes[2], "these two write the same modifiers")
        XCTAssertNotEqual(shapes[0], shapes[1],
                          "one row names a property the others do not, so it is a "
                            + "different shape and the pool must keep the two apart")
    }

    func testAHandlerIsPartOfTheShape() {
        let renders = Renders()
        let patch = renders.render(run([1, 2]) { number in
            HStack { Label("\(number)").fontSize(13).onTapped { } }
        })

        let without = Renders().render(run([1]) { number in
            HStack { Label("\(number)").fontSize(13) }
        })

        XCTAssertNotEqual(rows(patch)[0].shape, rows(without)[0].shape,
                          "a row that hears a tap is not the shape of one that does not")
    }

    func testARowHoldingAControlWithStateOfItsOwnHasNoShape() {
        let renders = Renders()

        // The same row twice but for one control, so what is being read is
        // that control and nothing else about the two.
        let patch = renders.render(run([1, 2]) { number in
            if number == 1 {
                // An Entry's caret, its selection and whether the platform is
                // typing into it are none of them properties, so nothing in a
                // shape could say two of them are alike.
                return HStack { Label("\(number)"); Entry("") }
            }

            return HStack { Label("\(number)"); Label("") }
        })

        let shapes = rows(patch).map { $0.shape }

        XCTAssertNil(shapes[0],
                     "a row is poolable only when every control in it is, and one that "
                       + "is not says nothing at all - which is the host's own default")
        XCTAssertNotNil(shapes[1], "the row beside it, differing only in that control, is")
    }

    func testARowThatAsksWhenItIsLoadedHasNoShape() {
        let renders = Renders()

        // The same row twice but for one handler, so what is being read is
        // that handler and nothing else about the two.
        let patch = renders.render(run([1, 2]) { number in
            if number == 1 {
                // A kept control never leaves the tree and never comes back
                // into it, so neither of these two would ever fire again. A row
                // that asks is built rather than answered with silence.
                return HStack { Label("\(number)").onLoaded { } }
            }

            return HStack { Label("\(number)") }
        })

        let shapes = rows(patch).map { $0.shape }

        XCTAssertNil(shapes[0],
                     "a row that hears when it is loaded is left out of the pool")
        XCTAssertNotNil(shapes[1], "the row beside it, differing only in that, is in it")
    }

    func testARowOutsideARecyclingLayoutIsNotShapedAtAll() {
        let renders = Renders()
        let patch = renders.render(
            VStack {
                AbsoluteLayout {
                    ForEach([1, 2], id: \.self) { number in
                        Label("\(number)")
                    }
                }
            }
            .body)

        XCTAssertEqual(rows(patch).map { $0.shape }, [nil, nil],
                       "nothing is shaped until a layout says its children are rows")
    }

    // MARK: - What crosses, and when

    func testTheLayoutSaysItRecyclesOnceAndNotAgain() {
        let renders = Renders()
        let first = renders.render(run([1, 2]) { Label("\($0)") })
        XCTAssertEqual(first.children.first { $0.type == .absoluteLayout }?.recycles, true)

        let second = renders.render(self.run([1, 2, 3]) { Label("\($0)") })
        XCTAssertNil(second.children.first { $0.type == .absoluteLayout }?.recycles,
                     "it did not change, so a message that rearranges the rows "
                        + "must not say it again")
    }

    func testAStandingRowDoesNotRepeatItsShape() {
        let renders = Renders()

        _ = renders.render(run([1, 2]) { Label("\($0)") })
        let second = renders.render(run([1, 2, 3]) { Label("\($0)") })

        let said = rows(second).map { $0.shape }

        XCTAssertEqual(said.count, 3, "a row arrived, so the whole arrangement is said")
        XCTAssertEqual(said[0], nil)
        XCTAssertEqual(said[1], nil)
        XCTAssertNotEqual(said[2], nil, "the row that arrived is the one that needs shaping")
        XCTAssertNotEqual(said[2], Recycling.none)
    }

    func testARowThatChangesShapeSaysSo() {
        let renders = Renders()
        var coloured = false

        let tree = {
            self.run([1, 2]) { number in
                var label = Label("\(number)")
                if coloured && number == 1 { label = label.textColor(.red) }
                return label
            }
        }

        _ = renders.render(tree())
        coloured = true
        let second = renders.render(tree())

        // Nothing moved and nothing arrived, so the patch is the sparse form
        // and carries exactly the row with something to say.
        XCTAssertEqual(rows(second).count, 1)
        XCTAssertNotNil(rows(second)[0].shape,
                        "the first row started naming a property, so what it looks "
                          + "like moved and the pool has to be told")
    }

    // MARK: - The number is the same everywhere

    func testTheSameRowIsShapedTheSameWayInTwoRenderers() {
        let tree = {
            self.run([1]) { number in
                HStack {
                    Label("\(number)").fontSize(13).textColor(.red)
                    BoxView().widthRequest(4)
                }
            }
        }

        // Two Differs, two sets of dictionaries: a shape read from an
        // unsorted walk of either would differ between these, and nothing
        // would ever be adopted.
        let one = rows(Renders().render(tree()))[0].shape
        let other = rows(Renders().render(tree()))[0].shape

        XCTAssertEqual(one, other)
        XCTAssertNotEqual(one, Recycling.none)

        // And the number itself, written down: Swift's own hashing is salted
        // per PROCESS, so two Differs inside this one would agree under it
        // and the assertion above would pass while a session stopped writing
        // the same bytes in every run. A literal is what says the arithmetic
        // is this side's own. Change it only with the shape's own rules.
        XCTAssertEqual(one, 962_238_212_922_186_302)
    }

    func testTheListPlacesItsRowsInALayoutThatRecycles() {
        let renders = Renders()
        let patch = renders.render(
            CollectionView(1...20) { number in
                Label("\(number)")
            }
            .body)

        XCTAssertEqual(patch.children.first { $0.type == .absoluteLayout }?.recycles, true,
                       "the list's rows are what a pool exists for")
    }

    func testTheCarouselPlacesItsCardsInALayoutThatRecycles() {
        let renders = Renders()
        let patch = renders.render(
            CarouselView(0..<10) { number in
                Label("\(number)")
            }
            .body)

        XCTAssertEqual(patch.children.first { $0.type == .absoluteLayout }?.recycles, true)
    }
}
