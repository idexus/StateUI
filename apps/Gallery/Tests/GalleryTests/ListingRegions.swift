// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The code a page shows, read from the code that runs: each region a source marks
/// `// listing: <name>` to `// listing: end` - `// listing: <name>, <name>` for code several listings show - a
/// name's regions in one file joined in order, the decoration left out; `// listing: <name> keep` keeps a region's
/// decoration, where the look is what it shows.
enum ListingRegions {
    /// The modifiers a listing leaves out - how a view looks rather than what it is or does. A line ending
    /// `// listing: keep` stays, where the look is the point.
    static let decoration: Set<String> = [
        "fontSize", "fontAttributes", "fontFamily", "textColor", "tint", "background", "barBackgroundColor",
        "barForegroundColor", "padding", "margin", "spacing", "rowSpacing", "columnSpacing", "shape", "cornerRadius",
        "horizontalTextAlignment", "verticalTextAlignment", "accessibilityIdentifier", "accessibilityLabel",
        "accessibilityHint",
    ]

    /// The extensions of the sources a region may stand in.
    static let extensions: Set = ["swift", "java", "kt", "js", "mjs", "c", "h", "cpp", "hpp", "metal", "glsl", "hlsl"]

    /// Every listing the Gallery's sources and hosts mark, by name - or what is wrong with their marks. A name
    /// marked in several files joins them in the order of their paths, each part headed by the path of the file
    /// it stands in.
    static func all() throws -> (listings: [String: String], problems: [String]) {
        var listings: [String: String] = [:]
        var problems: [String] = []
        let files = try (GallerySources.files(under: "Sources", extensions: extensions)
            + GallerySources.files(under: "Platforms", extensions: extensions))
            .filter { !$0.path.hasSuffix("/Listings.swift") }

        for file in files {
            // A view's code leaves its decoration out; a host's stands as written, whatever its language.
            let read = regions(in: file.text, swift: file.path.hasPrefix("Sources/") && file.path.hasSuffix(".swift"))
            problems += read.problems.map { "\(file.path): \($0)" }

            for (name, text) in read.regions {
                let part = "// \(file.path)\n\(text)"
                listings[name] = listings[name].map { $0 + "\n\n" + part } ?? part
            }
        }

        return (listings, problems)
    }

    /// The regions `text` marks, by name, each name's joined in order with a blank line between; Swift's leave
    /// out the decoration, another language's stand as written.
    static func regions(in text: String, swift: Bool) -> (regions: [(String, String)], problems: [String]) {
        var regions: [(name: String, text: String)] = []
        var problems: [String] = []
        var open: [String]?
        var keepsLook = false
        var lines: [Substring] = []
        var skipped: Int?

        for (number, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let marker = line.trimmingCharacters(in: .whitespaces)
            if marker.hasPrefix("// listing: "), !marker.hasSuffix("// listing: keep") {
                let name = String(marker.dropFirst("// listing: ".count))
                if name == "end" {
                    guard let opened = open else {
                        problems.append("line \(number + 1) ends a region none began")
                        continue
                    }
                    // Each region is moved left on its own, so one cut from inside a type stands beside one
                    // cut from the file's top - unless an earlier region of the name left a type open, inside
                    // which it then stands.
                    for name in opened {
                        if let at = regions.firstIndex(where: { $0.name == name }) {
                            let text = dedented(lines)
                            let closing = text.prefix { $0 == "}" }.count
                            let depth = max(0, openBraces(in: regions[at].text) - closing)
                            regions[at].text += "\n\n" + indented(text, by: depth * 4)
                        } else {
                            regions.append((name, dedented(lines)))
                        }
                    }
                    open = nil
                } else if let opened = open {
                    problems.append("line \(number + 1) begins `\(name)` inside `\(opened.joined(separator: ", "))`")
                } else {
                    keepsLook = name.hasSuffix(" keep")
                    open = (keepsLook ? String(name.dropLast(" keep".count)) : name).components(separatedBy: ", ")
                    lines = []
                }
                continue
            }
            guard open != nil else { continue }

            if swift, !keepsLook, skipped != nil || isDecoration(marker) {
                // The modifier's call is left out; what follows its closing bracket stays, on the line before.
                let after = remainder(of: marker, depth: &skipped)
                if !after.isEmpty, let last = lines.indices.last { lines[last] += after }
                continue
            }
            lines.append(line.hasSuffix("// listing: keep")
                ? Substring(line.dropLast("// listing: keep".count).trimmingSuffix())
                : line)
        }
        if let opened = open { problems.append("`\(opened.joined(separator: ", "))` is never ended") }

        return (regions.map { ($0.name, $0.text) }, problems)
    }

    /// Whether `line` is a decoration modifier the listing leaves out.
    private static func isDecoration(_ line: String) -> Bool {
        guard line.hasPrefix("."), !line.hasSuffix("// listing: keep") else { return false }
        return decoration.contains(String(line.dropFirst().prefix { $0.isLetter }))
    }

    /// What follows a decoration modifier's call on `line`, once the call closes there; `depth` is how far
    /// inside the call the line begins, nil before it opens and once it closes.
    private static func remainder(of line: String, depth: inout Int?) -> String {
        var open = depth ?? 0
        var quoted = false
        var escaped = false

        for (offset, character) in line.enumerated() {
            if quoted {
                if escaped { escaped = false } else if character == "\\" { escaped = true } else if character == "\"" {
                    quoted = false
                }
                continue
            }
            switch character {
            case "\"": quoted = true
            case "(", "[", "{": open += 1
            case ")", "]", "}":
                open -= 1
                if open == 0 {
                    depth = nil
                    return String(line.dropFirst(offset + 1)).trimmingCharacters(in: .whitespaces)
                }
            default: break
            }
        }

        depth = open
        return ""
    }

    /// How many braces `text` leaves open, its strings and comments aside.
    private static func openBraces(in text: String) -> Int {
        var open = 0
        for line in text.split(separator: "\n") {
            var quoted = false
            var previous: Character = " "
            for character in line {
                defer { previous = character }
                if character == "\"", previous != "\\" { quoted.toggle() }
                if quoted { continue }
                if character == "/", previous == "/" { break }
                if character == "{" { open += 1 }
                if character == "}" { open -= 1 }
            }
        }
        return open
    }

    /// The text moved right by `spaces`, its empty lines left empty.
    private static func indented(_ text: String, by spaces: Int) -> String {
        guard spaces > 0 else { return text }
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "" : String(repeating: " ", count: spaces) + $0 }
            .joined(separator: "\n")
    }

    /// The lines moved left as one, as far as the least indented allows.
    private static func dedented(_ lines: [Substring]) -> String {
        let indent = lines.filter { !$0.allSatisfy(\.isWhitespace) }.map { $0.prefix { $0 == " " }.count }.min() ?? 0
        return lines.map { $0.allSatisfy(\.isWhitespace) ? "" : String($0.dropFirst(indent)) }
            .joined(separator: "\n")
    }
}

extension Substring {
    /// The text without its trailing spaces.
    fileprivate func trimmingSuffix() -> Substring {
        var text = self
        while text.last == " " { text = text.dropLast() }
        return text
    }
}
