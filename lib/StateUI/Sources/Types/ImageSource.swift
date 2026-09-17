// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Where a picture comes from.
//
// It is a type rather than a String for one reason, and it is the same reason
// Color is not a String: a picture may be TWO pictures, one per theme. Black
// artwork that reads well on a white page disappears on a dark one. The half
// in force is picked by the differ as the element showing it is built, exactly
// as a Color's is - so ONE name crosses, the host binds nothing, and that
// element is built again when the system flips. See Types/Color.swift.
//
// Not a tint: a tint paints a picture in one colour, while a second file keeps
// artwork of any colours as it was drawn. Two files it is.

/// A picture, by file name.
///
///     Image("tab_list.png")
///     ToolbarItem("Media").icon("tab_list.png")
///     Image(light: "tab_list.png", dark: "tab_list_dark.png")
///
/// A file in the application's `Resources/Images`, by name. An SVG is asked
/// for by its `.png` name - `tab_list.svg` as `tab_list.png` - and the host
/// finds the SVG where no PNG of that name exists. A plain string is one of
/// these, so only artwork that differs between the themes needs the type
/// written out.
public struct ImageSource: Equatable, Sendable, ExpressibleByStringLiteral, HostRepresentable {
    /// The file, by name.
    public let file: String

    /// The file to use when the system is in dark mode, when there is one.
    public let dark: String?

    /// One picture, by file name.
    public init(_ file: String) {
        self.file = file
        self.dark = nil
    }

    /// Two files, one per theme. The half in force is picked by the differ,
    /// as the element showing it is built.
    ///
    ///     ImageSource(light: "logo.png", dark: "logo_dark.png")
    ///
    /// For artwork that would vanish into one of the two backgrounds. A
    /// picture that reads on both is one file and a plain string.
    public init(light: String, dark: String) {
        self.file = light
        self.dark = dark
    }

    /// What lets every one-picture call site stay a plain string:
    /// `Image("tab_list.png")`, `.icon("tab_list.png")`.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// Whether it names anything at all - what a view asks before drawing one.
    public var isEmpty: Bool { file.isEmpty }

    /// The one name that crosses - and it crosses as TEXT, not as a `.name`
    /// riding the session's dictionary, which is what a style key or a font
    /// family does.
    ///
    /// The difference is whether the vocabulary is BOUNDED. An application has
    /// a handful of styles and a handful of fonts, so numbering them costs one
    /// dictionary entry each and pays for itself on every row. A picture may
    /// be a url built per item - an avatar, a thumbnail - and the dictionary
    /// is the session's, never emptied: numbering those would grow it without
    /// end for names used once. So this stays text, and the rule that keeps
    /// the wire honest is read as "a name is text when there can be no end of
    /// them".
    ///
    /// A picture drawn twice is BOTH, `.themed`, for the differ to pick from
    /// as it builds the element showing it - the way a colour pair is.
    public var propValue: PropValue {
        guard let dark else { return .string(file) }

        return .themed(light: .string(file), dark: .string(dark))
    }

    /// A picture back: one file's name, or a pair of them - nil for anything
    /// else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        switch propValue {
        case .string(let file):
            self.init(file)
        case .themed(light: .string(let light), dark: .string(let dark)):
            self.init(light: light, dark: dark)
        default:
            return nil
        }
    }

    /// Read back off a node, for the templates that are handed an item and have
    /// to draw it - a pair coming back as the pair it was written as.
    init(_ value: PropValue?) {
        if case .themed(let light, let dark) = value {
            self.init(light: light.string ?? "", dark: dark.string ?? "")
        } else {
            self.init(value?.string ?? "")
        }
    }
}
