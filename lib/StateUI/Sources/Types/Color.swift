// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A colour, held as what it IS: four channels.
//
// It is written as hex - `Color("#512BD4")` - as channels -
// `Color(red: 81, green: 43, blue: 212)` - or by name, camelCased: `.red`,
// `.lightGray`, `.cornflowerBlue`.
//
// The parser is THIS side's, it reads hex and nothing else, and what crosses
// the wire is four bytes - see `PropValue.color`. Leaving the reading to a
// host would put the definition of what a colour may be inside that host's
// parser, and every other host would then have to reproduce that parser
// exactly or differ in silence.
//
// Eight bits per channel loses nothing this API can express: every constructor
// here produces them, over the sRGB channels a host draws them in.
// Holding them also makes equality mean the COLOUR rather than its spelling -
// `Color("#ff0000")` and `.red` are one value, so two spellings of one colour
// are not a change and nothing is sent for them.
//
// THE THEME IS PICKED IN THE DIFFER. A colour written `Color(light:dark:)`
// travels as BOTH halves - `PropValue.themed` - until the differ builds the
// element wearing it, which picks the half `AppInfo.requestedTheme` says and
// records that read against the element. So a theme change builds exactly the
// elements wearing a pair and nothing around them; a pair written outside
// every build - into a session from a handler, in a style sheet made once - is
// right in both themes; and nothing in the host binds anything. See
// `element` in Core/Diff.swift. A pair in a state the HOST carries crosses as
// the half in force, and the element handing that state on reads the theme -
// see `State.Storage.wearThemedPair()`.

/// A colour.
///
///     Color("#512BD4")
///     Color.cornflowerBlue
///     Color(light: .white, dark: .black)
///
/// Written as hex or by name, and as a PAIR where the two themes want
/// different colours - `Color(light:dark:)` is one value that goes wherever a
/// colour goes. Held as four 8-bit channels, so two spellings of one colour
/// are equal and neither is a change worth sending.
public struct Color: Equatable, Sendable, HostRepresentable {
    /// The four sRGB channels of one colour, 0-255 each - what crosses the
    /// wire.
    struct Rgba: Equatable, Sendable {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
        let alpha: UInt8
    }

    /// The colour itself - the one in force unless the system is dark and
    /// this colour was written with a dark half.
    let light: Rgba

    /// What to use when the system is in dark mode, when a colour says.
    ///
    /// A colour with one of these is a PAIR, written `Color(light:dark:)`.
    /// Nothing is bound here: the half in force is picked by the differ, as
    /// the element wearing the colour is built - see `propValue`.
    let dark: Rgba?

    /// A colour from hex: "#RGB", "#ARGB", "#RRGGBB" or "#AARRGGBB", with or
    /// without the leading `#` - the alpha, when it is written, first.
    ///
    /// Hex and nothing else - a colour NAME is `Color.red` and its kin, which
    /// the compiler checks where a string could not. Anything else traps
    /// naming the text: a colour is written as a literal, so it fails the
    /// first time the code runs rather than drawing something nobody chose.
    public init(_ hex: String) {
        guard let parsed = Color.channels(of: hex) else {
            preconditionFailure(
                "'\(hex)' is not a colour: write hex - #RGB, #ARGB, #RRGGBB or "
                    + "#AARRGGBB - or one of Color's named colours")
        }

        self.light = parsed
        self.dark = nil
    }

    /// The same color named twice, once for each theme.
    ///
    ///     static let surface = Color(light: .white, dark: AppColors.offBlack)
    ///
    /// It is a Color, so it goes anywhere a Color goes: in a `Style`, on a
    /// control, into a page's session, into a state the host carries. The half
    /// in force is picked as the element wearing it - or handing the state on
    /// - is built, and that element is built again when the system theme
    /// changes, so each of them is right in both.
    public init(light: Color, dark: Color) {
        self.light = light.light
        self.dark = dark.light
    }

    /// The channels themselves, and the ones for dark mode when there are any.
    init(_ light: Rgba, dark: Rgba? = nil) {
        self.light = light
        self.dark = dark
    }

    /// A colour from its channels: red, green and blue, each 0-255, and an
    /// alpha from 0, invisible, to 255, opaque - the default.
    ///
    ///     Color(red: 81, green: 43, blue: 212)
    ///     Color(red: 81, green: 43, blue: 212, alpha: 128)
    ///
    /// Whole numbers, as a channel holds them, so a fraction is refused where
    /// it is written. A value outside 0-255 is held to the range rather than
    /// refused.
    public init(red: Int, green: Int, blue: Int, alpha: Int = 255) {
        self.init(Rgba(
            red: Color.channel(red),
            green: Color.channel(green),
            blue: Color.channel(blue),
            alpha: Color.channel(alpha)))
    }

    /// The colour under the wire's own colour tag - four bytes, which colours
    /// have because they are the value a tree carries most of and the cheapest
    /// to say exactly. Nothing in the host parses a colour or has to know what
    /// one may look like.
    ///
    /// A pair is BOTH, `.themed`, for the differ to pick from as it builds the
    /// element wearing it - see the head of this file.
    public var propValue: PropValue {
        guard let dark else { return Color.tagged(light) }

        return .themed(light: Color.tagged(light), dark: Color.tagged(dark))
    }

    /// A colour back: four channels, or a pair of them - nil for anything
    /// else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        switch propValue {
        case .color(let red, let green, let blue, let alpha):
            self.init(Rgba(red: red, green: green, blue: blue, alpha: alpha))

        case .themed(light: .color(let red, let green, let blue, let alpha),
                     dark: .color(let darkRed, let darkGreen, let darkBlue, let darkAlpha)):
            self.init(
                Rgba(red: red, green: green, blue: blue, alpha: alpha),
                dark: Rgba(red: darkRed, green: darkGreen, blue: darkBlue, alpha: darkAlpha))

        default:
            return nil
        }
    }

    /// Four channels under the colour tag.
    private static func tagged(_ channels: Rgba) -> PropValue {
        .color(red: channels.red, green: channels.green, blue: channels.blue, alpha: channels.alpha)
    }

    // A colour crosses as its four bytes wherever it crosses, so there is no
    // way back to "#AARRGGBB" here and there should not be one. Reading hex is
    // how a colour is WRITTEN in source - that half is below.

    // MARK: - Reading hex

    /// The channels a hex string names, or nil when it names none.
    ///
    /// Four lengths: three and four digits are the shorthand where each digit
    /// stands for both of its pair, six and eight the full form. Alpha comes
    /// FIRST in the four- and eight-digit forms, which is what ARGB means.
    static func channels(of text: String) -> Rgba? {
        var digits: [UInt8] = []
        digits.reserveCapacity(8)

        for scalar in text.unicodeScalars.dropFirst(text.hasPrefix("#") ? 1 : 0) {
            guard let digit = digit(scalar), digits.count < 8 else { return nil }
            digits.append(digit)
        }

        switch digits.count {
        case 3:
            return Rgba(
                red: digits[0] * 17, green: digits[1] * 17, blue: digits[2] * 17, alpha: 255)
        case 4:
            return Rgba(
                red: digits[1] * 17, green: digits[2] * 17, blue: digits[3] * 17,
                alpha: digits[0] * 17)
        case 6:
            return Rgba(
                red: byte(digits[0], digits[1]),
                green: byte(digits[2], digits[3]),
                blue: byte(digits[4], digits[5]),
                alpha: 255)
        case 8:
            return Rgba(
                red: byte(digits[2], digits[3]),
                green: byte(digits[4], digits[5]),
                blue: byte(digits[6], digits[7]),
                alpha: byte(digits[0], digits[1]))
        default:
            return nil
        }
    }

    /// One hex digit's value, or nil for anything that is not one.
    private static func digit(_ scalar: Unicode.Scalar) -> UInt8? {
        switch scalar.value {
        case 48...57:
            return UInt8(scalar.value - 48)  // 0-9
        case 97...102:
            return UInt8(scalar.value - 87)  // a-f
        case 65...70:
            return UInt8(scalar.value - 55)  // A-F
        default:
            return nil
        }
    }

    private static func byte(_ high: UInt8, _ low: UInt8) -> UInt8 {
        high << 4 | low
    }

    /// An Int as a channel, held to the range a channel has.
    private static func channel(_ value: Int) -> UInt8 {
        UInt8(value < 0 ? 0 : (value > 255 ? 255 : value))
    }

}

// MARK: - Named colors
//
// The named colours that come up in practice, each with its CSS name and
// value. Anything else is one `Color("#…")` away - the full CSS list
// is 140 names, and repeating all of them here would be noise.

extension Color {
    /// Nothing at all, #00FFFFFF.
    public static let transparent = Color("#00FFFFFF")

    /// Black, #000000.
    public static let black = Color("#000000")

    /// White, #FFFFFF.
    public static let white = Color("#FFFFFF")

    /// Gray, #808080.
    public static let gray = Color("#808080")

    /// Light gray, #D3D3D3.
    public static let lightGray = Color("#D3D3D3")

    /// Dark gray, #A9A9A9 - lighter than `.gray` despite the CSS name.
    public static let darkGray = Color("#A9A9A9")

    /// Dim gray, #696969.
    public static let dimGray = Color("#696969")

    /// Silver, #C0C0C0.
    public static let silver = Color("#C0C0C0")

    /// White smoke, #F5F5F5.
    public static let whiteSmoke = Color("#F5F5F5")

    /// Red, #FF0000.
    public static let red = Color("#FF0000")

    /// Firebrick, #B22222.
    public static let firebrick = Color("#B22222")

    /// Tomato, #FF6347.
    public static let tomato = Color("#FF6347")

    /// Orange, #FFA500.
    public static let orange = Color("#FFA500")

    /// Gold, #FFD700.
    public static let gold = Color("#FFD700")

    /// Yellow, #FFFF00.
    public static let yellow = Color("#FFFF00")

    /// Green, the dark one: #008000 - `.lime` is #00FF00.
    public static let green = Color("#008000")

    /// Lime, #00FF00.
    public static let lime = Color("#00FF00")

    /// Forest green, #228B22.
    public static let forestGreen = Color("#228B22")

    /// Teal, #008080.
    public static let teal = Color("#008080")

    /// Cyan, #00FFFF.
    public static let cyan = Color("#00FFFF")

    /// Blue, #0000FF.
    public static let blue = Color("#0000FF")

    /// Navy, #000080.
    public static let navy = Color("#000080")

    /// Dodger blue, #1E90FF.
    public static let dodgerBlue = Color("#1E90FF")

    /// Cornflower blue, #6495ED.
    public static let cornflowerBlue = Color("#6495ED")

    /// Steel blue, #4682B4.
    public static let steelBlue = Color("#4682B4")

    /// Light blue, #ADD8E6.
    public static let lightBlue = Color("#ADD8E6")

    /// Purple, #800080.
    public static let purple = Color("#800080")

    /// Indigo, #4B0082.
    public static let indigo = Color("#4B0082")

    /// Violet, #EE82EE.
    public static let violet = Color("#EE82EE")

    /// Magenta, #FF00FF.
    public static let magenta = Color("#FF00FF")

    /// Pink, #FFC0CB.
    public static let pink = Color("#FFC0CB")

    /// Brown, #A52A2A.
    public static let brown = Color("#A52A2A")

    /// Maroon, #800000.
    public static let maroon = Color("#800000")

    /// Olive, #808000.
    public static let olive = Color("#808000")
}
