// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// The closed vocabularies a relay beneath a host numbers by hand - Java's constants - stand name for name and number
/// for number with the Swift enum each mirrors, both ways: a number one side renumbers, or a member one side adds,
/// fails here rather than compile and mean something else.
/// Design: docs/design/platforms/android/jni.md#numbers-across
@MainActor
final class RelayVocabularyTests: XCTestCase {
    /// Every Java constant statement says the Swift enum it mirrors - `// Swift: none` where it never crosses - and
    /// stands as that enum does.
    func testJavasConstantsStandAsTheSwiftTheyMirror() throws {
        let java = SourceTree.repository.appendingPathComponent("lib/StateUI/StateUI.Android/Java/stateui/android")
        var read = 0
        var broken: [String] = []
        let enums = try Self.swiftEnums()

        for file in try SourceTree.files(under: java, entering: SourceTree.entersSources) where file.hasSuffix(".java") {
            let text = try String(contentsOf: java.appendingPathComponent(file), encoding: .utf8)
            for group in Self.javaConstants(in: text) {
                read += 1
                guard let mirror = group.mirror else {
                    broken.append("\(file): \(group.names.joined(separator: ", ")) says no Swift it mirrors")
                    continue
                }
                guard mirror != "none" else { continue }
                guard let cases = enums[mirror] else {
                    broken.append("\(file): \(mirror) is no Swift enum of Int32")
                    continue
                }
                let java = Dictionary(uniqueKeysWithValues: zip(group.names, group.values))
                let swift = Dictionary(uniqueKeysWithValues: cases.map { (Self.screaming($0.name), $0.value) })
                if java != swift {
                    broken.append("\(file): \(mirror) - Java \(java.sorted { $0.key < $1.key }), "
                        + "Swift \(swift.sorted { $0.key < $1.key })")
                }
            }
        }

        XCTAssertGreaterThan(read, 15, "the walk read almost nothing")
        XCTAssertEqual(broken, [], broken.joined(separator: "\n"))
    }

    /// One `static final int` statement of a Java file: its names and values, and the Swift its marker names - the
    /// line comment `// Swift: <Enum>` standing right before it.
    private static func javaConstants(in text: String) -> [(mirror: String?, names: [String], values: [Int])] {
        var groups: [(mirror: String?, names: [String], values: [Int])] = []
        let lines = text.components(separatedBy: "\n")
        var index = 0
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            guard line.contains("static final int ") else {
                index += 1
                continue
            }
            let previous = index > 0 ? lines[index - 1].trimmingCharacters(in: .whitespaces) : ""
            var statement = line
            while !statement.contains(";"), index + 1 < lines.count {
                index += 1
                statement += " " + lines[index].trimmingCharacters(in: .whitespaces)
            }
            let mirror = previous.hasPrefix("// Swift: ") ? String(previous.dropFirst("// Swift: ".count)) : nil
            let body = statement.components(separatedBy: "static final int ").last?
                .components(separatedBy: ";").first ?? ""
            var names: [String] = []
            var values: [Int] = []
            for pair in body.components(separatedBy: ",") {
                let parts = pair.components(separatedBy: "=").map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2, let value = Int(parts[1]) else { continue }
                names.append(parts[0])
                values.append(value)
            }
            groups.append((mirror, names, values))
            index += 1
        }
        return groups
    }

    /// Every Swift `enum <Name>: Int32` the library and its hosts declare - nested ones by `<Outer>.<Name>` - with
    /// each case's name and number.
    private static func swiftEnums() throws -> [String: [(name: String, value: Int)]] {
        var found: [String: [(name: String, value: Int)]] = [:]
        let roots = ["lib/StateUI/Core/Sources", "lib/StateUI/StateUI.Host/Sources", "lib/StateUI/StateUI.Android/Sources"]
        for root in roots {
            let folder = SourceTree.repository.appendingPathComponent(root)
            for file in try SourceTree.files(under: folder, entering: SourceTree.entersSources) where file.hasSuffix(".swift") {
                let lines = try String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8)
                    .components(separatedBy: "\n")
                var outer: String?
                for (number, line) in lines.enumerated() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if !line.hasPrefix(" "), let name = Self.declared(trimmed) { outer = name }
                    guard trimmed.hasPrefix("enum ") || trimmed.contains(" enum "),
                          let declared = Self.declared(trimmed), trimmed.contains(": Int32")
                    else { continue }
                    let key = line.hasPrefix(" ") ? "\(outer ?? "").\(declared)" : declared
                    found[key] = Self.cases(lines, from: number + 1)
                }
            }
        }
        return found
    }

    /// The name a declaration line declares - an enum, a struct, a class or an extension.
    private static func declared(_ line: String) -> String? {
        let words = line.components(separatedBy: CharacterSet(charactersIn: " :<{"))
        guard let keyword = words.firstIndex(where: { ["enum", "struct", "class", "extension"].contains($0) }),
              keyword + 1 < words.count, !words[keyword + 1].isEmpty
        else { return nil }
        return words[keyword + 1]
    }

    /// The cases of the enum whose body starts at line `start`, each number written or one past the last.
    private static func cases(_ lines: [String], from start: Int) -> [(name: String, value: Int)] {
        var cases: [(name: String, value: Int)] = []
        var depth = 1
        var next = 0
        for line in lines[start...] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            depth += trimmed.filter { $0 == "{" }.count - trimmed.filter { $0 == "}" }.count
            if depth <= 0 { break }
            guard depth == 1, trimmed.hasPrefix("case ") else { continue }
            for part in trimmed.dropFirst(5).components(separatedBy: ",") {
                let pieces = part.components(separatedBy: "=").map { $0.trimmingCharacters(in: .whitespaces) }
                guard let name = pieces.first, !name.isEmpty, !name.contains("(") else { continue }
                let value = pieces.count == 2 ? Int(pieces[1]) ?? next : next
                cases.append((name, value))
                next = value + 1
            }
        }
        return cases
    }

    /// `letGo` as Java spells a constant: `LET_GO`.
    private static func screaming(_ name: String) -> String {
        var spelled = ""
        for character in name {
            if character.isUppercase { spelled += "_" }
            spelled += character.uppercased()
        }
        return spelled
    }
}
