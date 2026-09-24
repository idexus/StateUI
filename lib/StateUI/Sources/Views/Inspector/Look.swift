// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The inspector's colours, measures, words and the one kind of button it has.
enum Look {
    static let ground = Color(light: Color("#F7F6FB"), dark: Color("#1C1A24"))
    static let edge = Color(light: Color("#D6D2E2"), dark: Color("#3A3647"))
    static let ink = Color(light: Color("#1B1A22"), dark: Color("#ECEAF4"))
    static let subtle = Color(light: Color("#6B6878"), dark: Color("#A29FB0"))
    static let built = Color(light: Color("#B4400A"), dark: Color("#FB923C"))
    static let carried = Color(light: Color("#15803D"), dark: Color("#4ADE80"))
    static let chosen = Color(light: Color("#E7E3F3"), dark: Color("#2E2A3B"))

    /// How wide a panel docked at the side stands.
    static let side = 460.0

    /// How far below a window's top a panel at the side begins - the height
    /// of a page's bar, which keeps its buttons clear.
    static let bar = 56.0

    /// One of the inspector's buttons.
    static func action(_ caption: String, _ run: @escaping () -> Void) -> Element {
        Button(caption)
            .fontSize(12)
            .textColor(ink)
            .background(.transparent)
            .stroke(edge)
            .strokeWidth(1)
            .shape(.roundedRectangle(7))
            .padding(10, 2)
            .margin(0, 0, 6, 4)
            .onClicked { run() }
    }

    /// One of the two pictures at the end of a panel's line along the bottom:
    /// a drawing in a twelve-unit box, the tap, and the word a screen reader
    /// and a script know it by.
    ///
    /// Drawn rather than typed: a font without the glyph draws an empty box.
    ///
    /// - Parameters:
    ///   - picture: the drawing - `expanding`, `folding` or `closing`.
    ///   - words: what it does, in a word.
    ///   - run: what a tap does.
    static func icon(_ picture: String, _ words: String, _ run: @escaping () -> Void) -> Element {
        Grid {
            Path(picture)
                .stroke(ink)
                .strokeWidth(1.5)
                .strokeLineCap(.round)
                .width(12)
                .height(12)
                .horizontalAlignment(.center)
                .verticalAlignment(.center)
                .ignoresInput(true)
        }
        .width(28)
        .height(24)
        .background(.transparent)
        .accessibilityLabel(words)
        .accessibilityIdentifier("stateui.inspector.\(words.lowercased())")
        .onTapped { run() }
    }

    /// Opening a folded panel out: the square a window is enlarged with.
    static let expanding = "M1.5 1.5 H10.5 V10.5 H1.5 Z"

    /// Folding it to one line: the bar a window is made small with.
    static let folding = "M1.5 9 H10.5"

    /// Closing it: a cross.
    static let closing = "M2 2 L10 10 M10 2 L2 10"

    /// One line of the chosen render's numbers.
    static func line(_ text: String) -> Element {
        Label(text)
            .fontSize(11)
            .textColor(subtle)
            .lineBreak(.tailTruncation)
    }

    /// How long one scene's part of the host's apply took, where it said.
    static func scene(_ host: InspectedHost?, at index: Int?) -> Double? {
        guard let host, let index, index < host.scenes.count else { return nil }

        return host.scenes[index]
    }

    /// Microseconds, whole and grouped by thousands.
    static func micros(_ value: Double) -> String {
        let whole = Int(value.rounded())
        var digits = String(whole)
        var grouped = ""

        while digits.count > 3 {
            grouped = " " + digits.suffix(3) + grouped
            digits = String(digits.dropLast(3))
        }

        return digits + grouped + " µs"
    }

    /// Milliseconds as seconds to a tenth.
    static func seconds(_ milliseconds: Double) -> String {
        let tenths = Int((milliseconds / 100).rounded())

        return "\(tenths / 10).\(tenths % 10) s"
    }

    /// A road, in a word.
    static func road(_ road: InspectedPass.Road) -> String {
        switch road {
        case .walk: return "walk"
        case .build: return "build"
        case .complete: return "complete"
        }
    }
}
