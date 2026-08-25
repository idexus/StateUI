// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The wire's oldest rule, made checkable: a STRING is text someone wrote.
//
// Everything else that crosses is a number. A closed vocabulary rides the
// member's own number, an open one rides the session dictionary, a value with
// parts rides as its parts. These guards are what keeps that true, because the
// way it slips is one enum at a time, each with a good local reason.
//
// The other half of the pairing lives on the C# side, in WireEnumTests.cs:
// this file says the SHAPE of a declaration is right, that one says the
// NUMBERS mean the same thing to MAUI. Neither can be written on the other
// side - only Swift can walk its own sources, and only C# can see MAUI.

import XCTest

@testable import StateUI

final class WireVocabularyTests: XCTestCase {
    /// No closed vocabulary may ride its spelling.
    ///
    /// `enum LineBreakMode: String` is what makes a binary wire spend four
    /// bytes of length and fourteen of UTF-8 saying `tailTruncation`, and the
    /// far side a string hash per property to read it back. There is no
    /// exemption list on purpose: nothing in this library needs a
    /// string-backed enum, and an enum that genuinely never crosses does not
    /// need a raw type at all.
    func testNoEnumInTheLibraryCarriesAStringRawValue() throws {
        var offenders: [String] = []

        for source in try Fixtures.allSources() {
            for (number, line) in source.text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)

                guard !code.hasPrefix("//"), !code.hasPrefix("///") else { continue }
                guard code.contains("enum "), code.contains(": String") else { continue }

                offenders.append("\(source.path):\(number + 1) \(code)")
            }
        }

        XCTAssertEqual(
            offenders, [],
            "a closed vocabulary must ride its NUMBER, not its spelling - "
                + "declare it `: Int32` with MAUI's own values and write it "
                + "as `.enumeration(rawValue)`")
    }

    /// Every case of a wire enum states its number out loud.
    ///
    /// Swift numbers an `Int32` enum from 0 in declaration order when nobody
    /// says otherwise, so a case inserted in the middle renumbers every case
    /// after it - silently, and only on this side. The far side goes on
    /// casting the old numbers to the new members and the interface fills with
    /// values nobody wrote. Half of these numbers are not declaration order in
    /// the first place (`FlexJustify` starts at 2, `FlexDirection` has Column
    /// at 2, `AbsoluteLayoutFlags.all` is -1), which is why the rule is that
    /// EVERY case says its own.
    func testEveryWireEnumNumbersEveryCaseExplicitly() throws {
        var offenders: [String] = []
        var checked = 0

        for source in try Fixtures.allSources() {
            var inside: String?
            var depth = 0

            for (number, line) in source.text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)

                if inside == nil, code.contains("enum "), code.contains(": Int32"), code.hasSuffix("{") {
                    inside = Self.name(ofEnumOn: code)
                    depth = 1
                    continue
                }

                guard let enumeration = inside else { continue }

                depth += code.filter { $0 == "{" }.count - code.filter { $0 == "}" }.count

                if depth <= 0 {
                    inside = nil
                    continue
                }

                guard code.hasPrefix("case ") else { continue }

                checked += 1

                if !code.contains(" = ") {
                    offenders.append("\(source.path):\(number + 1) \(enumeration).\(code)")
                }
            }
        }

        XCTAssertGreaterThan(
            checked, 100,
            "the scanner read almost no cases, so it is reading the wrong "
                + "thing rather than finding nothing wrong")

        XCTAssertEqual(
            offenders, [],
            "a case of an enum that crosses the wire must state its number - "
                + "an implicit one moves when a case is inserted above it, and "
                + "the far side is still casting the old numbers")
    }

    /// A vocabulary that crosses is declared `: Int32`, never `: Int`.
    ///
    /// `Int32` is what the wire's enumeration tag carries and what a C# enum
    /// reads back as, so `: Int` needs a conversion at every use - but that is
    /// the smaller half. The larger half is that every guard over these
    /// declarations, here and in WireEnumTests.cs, finds a vocabulary by its
    /// RAW TYPE. One declared the other way is invisible to all of them at
    /// once: no mirror is demanded, no numbers are compared, and it can ride
    /// the wire as a plain `.number` with nothing to say so.
    func testEveryVocabularyThatCrossesIsDeclaredInt32() throws {
        var offenders: [String] = []

        for source in try Fixtures.allSources() {
            let lines = source.text.split(separator: "\n", omittingEmptySubsequences: false)

            for (number, line) in lines.enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)

                guard !code.hasPrefix("//"), code.hasSuffix("{") else { continue }
                guard code.contains("enum "), code.contains(": Int,") else { continue }

                offenders.append("\(source.path):\(number + 1) \(code)")
            }
        }

        XCTAssertEqual(
            offenders, [],
            "declare it `: Int32` - every guard over these finds a vocabulary "
                + "by its raw type, so `: Int` is invisible to all of them")
    }

    /// No `propValue` hands a raw value straight to `.string`.
    ///
    /// This is the shape the drift takes: a vocabulary declares its spelling
    /// as its raw value and then writes that spelling, which reads perfectly
    /// well one type at a time and is thirty types deep before anyone counts.
    /// A raw value belongs in `.enumeration`; what goes in `.string` is what
    /// an author typed.
    func testNoPropValueWritesARawValueAsText() throws {
        var offenders: [String] = []

        for source in try Fixtures.allSources() {
            for (number, line) in source.text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)

                guard !code.hasPrefix("//") else { continue }

                // A raw value anywhere inside a `.string(` on one line - which
                // catches `.string(rawValue)`, `.string(value.rawValue)` and
                // the interpolated `"\(a.rawValue),\(b.rawValue)"` a packed
                // form would be made of.
                guard let opened = code.range(of: ".string(") else { continue }

                if code[opened.upperBound...].contains("rawValue") {
                    offenders.append("\(source.path):\(number + 1) \(code)")
                }
            }
        }

        XCTAssertEqual(
            offenders, [],
            "a member of a closed vocabulary crosses as `.enumeration(rawValue)`")
    }

    /// The name in `public enum Foo: Int32, Sendable {`, or the whole line
    /// when it is written some way this cannot read - which shows up in the
    /// failure message rather than being skipped.
    private static func name(ofEnumOn code: String) -> String {
        guard let after = code.range(of: "enum ") else { return code }

        let rest = code[after.upperBound...]
        let name = rest.prefix { $0.isLetter || $0.isNumber || $0 == "_" }

        return name.isEmpty ? code : String(name)
    }
}
