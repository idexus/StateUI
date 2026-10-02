// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// What every host's keyboard and checking do for the words a view takes, by what the tree says of them.
final class InputTraitsTests: XCTestCase {
    /// Nothing said leaves the platform its own capitals, with checking, correction and prediction on.
    func testTheDefaultIsThePlatformsOwn() {
        let traits = InputTraits(spellChecked: true, predicted: true, purpose: nil)

        XCTAssertEqual(traits, InputTraits(spellChecked: true, predicted: true, purpose: .default))
        XCTAssertEqual(traits.keys, .words)
        XCTAssertEqual(traits.capitals, .platform)
        XCTAssertTrue(traits.checksSpelling && traits.corrects && traits.predicts)
    }

    /// Plain words are taken as typed: no capitals, no checking, no correction, no prediction - a code, a login.
    func testPlainWordsAreTakenAsTyped() {
        let traits = InputTraits(spellChecked: true, predicted: true, purpose: .plain)

        XCTAssertEqual(traits.capitals, .none)
        XCTAssertFalse(traits.checksSpelling || traits.corrects || traits.predicts)
    }

    /// An address takes no capitals and its own keys; text starts its sentences in capitals; a number and a
    /// telephone take their keys; a chat offers emoji.
    func testEachPurposeTakesItsKeysAndItsCapitals() {
        func traits(_ purpose: InputPurpose) -> InputTraits {
            InputTraits(spellChecked: true, predicted: true, purpose: purpose)
        }

        XCTAssertEqual([traits(.email).keys, traits(.url).keys], [.email, .url])
        XCTAssertEqual([traits(.email).capitals, traits(.url).capitals], [.none, .none])
        XCTAssertEqual(traits(.text).capitals, .sentences)
        XCTAssertEqual([traits(.numeric).keys, traits(.telephone).keys], [.number, .telephone])
        XCTAssertTrue(traits(.chat).offersEmoji)
    }

    /// Spell checking and prediction turned off stay off whatever the purpose; prediction off takes correction
    /// with it.
    func testWhatTheTreeTurnsOffStaysOff() {
        let traits = InputTraits(spellChecked: false, predicted: false, purpose: .text)

        XCTAssertFalse(traits.checksSpelling || traits.corrects || traits.predicts)
        XCTAssertEqual(traits.capitals, .sentences)
    }

    /// A field's return key is the tree's, else a search's for a search field and the platform's own for another.
    func testAReturnKeyUnwrittenIsTheFieldsOwn() {
        XCTAssertEqual(InputTraits.submitLabel(nil, searching: true), .search)
        XCTAssertEqual(InputTraits.submitLabel(nil, searching: false), .default)
        XCTAssertEqual(InputTraits.submitLabel(.go, searching: true), .go)
        XCTAssertEqual(InputTraits.submitLabel(.done, searching: false), .done)
    }
}
