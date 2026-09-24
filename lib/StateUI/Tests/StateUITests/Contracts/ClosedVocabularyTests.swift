// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The host boundary's oldest rule, made checkable: a STRING is text someone
// wrote.
//
// Everything else a host is handed is a number or a name. A closed vocabulary
// rides the member's own number, an open one its `.name`, a value with parts
// its parts. These guards are what keeps that true, because the way it slips
// is one enum at a time, each with a good local reason.
//
// This file says the SHAPE of a declaration is right. That its NUMBERS mean
// the same member to a host is for each host to prove, since only a host can
// see its toolkit's members.

import XCTest

@_spi(Host) @testable import StateUI

final class ClosedVocabularyTests: XCTestCase {
    /// No closed vocabulary may ride its spelling.
    ///
    /// `enum LineBreak: String` is what hands a host `tailTruncation` to
    /// compare as text where a member number would do, and what lets a
    /// spelling pass for authored words. There is no exemption list on
    /// purpose: nothing in this library needs a string-backed enum, and an
    /// enum that genuinely never crosses does not need a raw type at all.
    func testNoEnumInTheLibraryCarriesAStringRawValue() throws {
        var offenders: [String] = []

        for source in try SourceTree.allSources() {
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
                + "declare it `: Int32` with stable numbers of its own and write it "
                + "as `.enumeration(rawValue)`")
    }

    /// Every case of a closed vocabulary states its number out loud.
    ///
    /// Swift numbers an `Int32` enum from 0 in declaration order when nobody
    /// says otherwise, so a case inserted in the middle renumbers every case
    /// after it, silently. The numbers are the vocabulary's own contract - in
    /// the patch a host translates and in every dump a test compares - and do
    /// not move by accident. Some values are not declaration order in the
    /// first place (a flag set numbers its bits), which is why the
    /// rule is that EVERY case says its own.
    func testEveryClosedVocabularyNumbersEveryCaseExplicitly() throws {
        var offenders: [String] = []
        var checked = 0

        for source in try SourceTree.allSources() {
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
            "a case of a closed vocabulary must state its number - an implicit "
                + "one moves when a case is inserted above it")
    }

    /// A vocabulary that crosses is declared `: Int32`, never `: Int`.
    ///
    /// `Int32` is what `.enumeration` carries, so `: Int` needs a conversion
    /// at every use - but that is the smaller half. The larger half is that
    /// every guard over these declarations finds a vocabulary by its RAW
    /// TYPE. One declared the other way is invisible to all of them at once:
    /// no number of it is checked, and it can reach a host as a plain
    /// `.number` with nothing to say so.
    func testEveryVocabularyThatCrossesIsDeclaredInt32() throws {
        var offenders: [String] = []

        for source in try SourceTree.allSources() {
            let lines = source.text.split(separator: "\n", omittingEmptySubsequences: false)

            for (number, line) in lines.enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)

                guard !code.hasPrefix("//"), code.hasSuffix("{") else { continue }
                guard code.contains("enum "),
                      code.contains(": Int,") || code.contains(": Int {")
                else { continue }

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

        for source in try SourceTree.allSources() {
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
