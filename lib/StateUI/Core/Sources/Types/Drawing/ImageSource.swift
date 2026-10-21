// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Where a picture comes from: one file, or one for each theme.
// Design: docs/design/types/color-and-theme.md#pictures-for-each-theme

/// A picture: a file by name - one, or one for each theme - an icon of the
/// platform's own, or an encoded picture's bytes.
///
///     Image("tab_list.png")
///     ToolbarItem("Media").icon("tab_list.png")
///     Image(ImageSource(light: "tab_list.png", dark: "tab_list_dark.png"))
///     Image(.icon(.share))
///     Image(ImageSource(bytes: downloaded))
///
/// A file is in the application's `Resources/Images`, by name. An SVG is asked
/// for by its `.png` name - `tab_list.svg` as `tab_list.png` - and the host
/// finds the SVG where no PNG of that name exists. A plain string is one of
/// these, so only artwork that differs between the themes needs the type
/// written out.
public struct ImageSource: Equatable, Sendable, ExpressibleByStringLiteral, HostRepresentable {
    /// What the picture is: a file - and the one for the dark theme - an icon, or bytes.
    private enum Kind: Equatable, Sendable {
        case file(String, dark: String?)
        case icon(Icon)
        case bytes([UInt8])
    }

    private let kind: Kind

    private init(_ kind: Kind) {
        self.kind = kind
    }

    /// The file, by name; empty for an icon or bytes.
    public var file: String {
        guard case .file(let file, _) = kind else { return "" }
        return file
    }

    /// The file to use when the system is in dark mode, when there is one.
    public var dark: String? {
        guard case .file(_, let dark) = kind else { return nil }
        return dark
    }

    /// One picture, by file name.
    public init(_ file: String) {
        self.init(.file(file, dark: nil))
    }

    /// Two files, one for each theme; the element showing the picture follows
    /// the system theme.
    ///
    ///     ImageSource(light: "logo.png", dark: "logo_dark.png")
    ///
    /// For artwork that would vanish into one of the two backgrounds. A
    /// picture that reads on both is one file and a plain string.
    public init(light: String, dark: String) {
        self.init(.file(light, dark: dark))
    }

    /// The platform's own icon for `icon`, drawn in the color of the words
    /// around it where the platform tints its icons.
    ///
    ///     Button("Share").icon(.icon(.share))
    public static func icon(_ icon: Icon) -> ImageSource {
        ImageSource(.icon(icon))
    }

    /// A picture from its encoded bytes - a PNG or a JPEG the application
    /// holds, downloaded or made - decoded by the platform.
    ///
    ///     Image(ImageSource(bytes: avatar))
    public init(bytes: [UInt8]) {
        self.init(.bytes(bytes))
    }

    /// What lets every one-picture call site stay a plain string:
    /// `Image("tab_list.png")`, `.icon("tab_list.png")`.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// Whether it names anything at all - what a view asks before drawing one.
    public var isEmpty: Bool {
        switch kind {
        case .file(let file, _): file.isEmpty
        case .icon: false
        case .bytes(let bytes): bytes.isEmpty
        }
    }

    /// A file's name as text, or both names as a themed pair; an icon as its
    /// number in the vocabulary; bytes as bytes.
    ///
    /// Design: docs/design/types/values.md#text-and-names
    public var propValue: PropValue {
        switch kind {
        case .file(let file, nil): .string(file)
        case .file(let file, let dark?): .themed(light: .string(file), dark: .string(dark))
        case .icon(let icon): .enumeration(icon.rawValue)
        case .bytes(let bytes): .bytes(bytes)
        }
    }

    /// A picture back: one file's name, a pair of them, an icon or bytes - nil
    /// for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        switch propValue {
        case .string(let file):
            self.init(file)
        case .themed(light: .string(let light), dark: .string(let dark)):
            self.init(light: light, dark: dark)
        case .enumeration(let number):
            guard let icon = Icon(rawValue: number) else { return nil }
            self.init(.icon(icon))
        case .bytes(let bytes):
            self.init(.bytes(bytes))
        default:
            return nil
        }
    }

    /// A picture read from a property's value - the kind it was written as,
    /// anything else as one file's name, empty where there is none.
    init(_ value: PropValue?) {
        if let value, let read = ImageSource(propValue: value) {
            self = read
        } else {
            self.init(value?.string ?? "")
        }
    }
}
