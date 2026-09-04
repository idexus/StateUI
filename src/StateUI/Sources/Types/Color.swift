// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Color, as MAUI defines it - but held as what it IS, four channels.
//
// The factory methods keep MAUI's names - `Color.fromArgb("#512BD4")`,
// `Color.fromRgb(81, 43, 212)` - and the named colors keep the names from MAUI's
// `Colors` class, camelCased: `.red`, `.lightGray`, `.cornflowerBlue`.
//
// The parser is THIS side's, it reads hex and nothing else, and what crosses
// the wire is four bytes - see `PropValue.color`. Leaving the reading to MAUI's
// own `Color.TryParse` would put the definition of what a colour may be inside
// MAUI - the named CSS colours, `rgb()`, `hsl()`, four lengths of hex - and a
// second host would then have to reproduce that parser exactly or differ in
// silence.
//
// Eight bits per channel loses nothing this API can express: every constructor
// here produces them, and MAUI's floats are 0-1 over the same sRGB channels.
// Holding them also makes equality mean the COLOUR rather than its spelling -
// `Color("#ff0000")` and `.red` are one value, so two spellings of one colour
// are not a change and nothing is sent for them.
//
// THE THEME IS RESOLVED HERE. A colour written `Color(light:dark:)` picks its
// half as the value is put on a node, against `AppInfo.requestedTheme` - the
// environment the host pushes before the first render. That read is RECORDED,
// exactly as any other state read during a build, so a theme change rebuilds
// precisely the views that asked and nothing else, and nothing on the far side
// binds anything. See Core/Invalidation.swift and Views/Style.swift.

/// A colour. MAUI: Color.
///
///     Color("#512BD4")
///     Color.cornflowerBlue
///     Color(light: .white, dark: .black)
///
/// Written as hex or by one of MAUI's names, and as a PAIR where the two
/// themes want different colours - `Color(light:dark:)` is one value that goes
/// wherever a colour goes. Held as four 8-bit channels, so two spellings of
/// one colour are equal and neither is a change worth sending.
public struct Color: Equatable, Sendable {
    /// The four channels of one colour, 0-255 each - what MAUI holds as four
    /// floats over the same sRGB channels, and what crosses the wire.
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
    /// A colour with one of these is what MAUI writes as
    /// `{AppThemeBinding Light=…, Dark=…}`. Nothing is bound here: the half in
    /// force is chosen as the value is written onto a node - see `resolved`.
    let dark: Rgba?

    /// A colour from the four channels, for a value coming BACK from the host
    /// - where a stopped journey says how far it had walked. No dark half: what
    /// the host reports is what is on the screen, which is one colour.
    init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        light = Rgba(red: red, green: green, blue: blue, alpha: alpha)
        dark = nil
    }

    /// A colour from hex: "#RGB", "#ARGB", "#RRGGBB" or "#AARRGGBB", with or
    /// without the leading `#`. `Color.fromArgb` says the same thing in MAUI's
    /// own words.
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
    /// MAUI: `{AppThemeBinding Light=…, Dark=…}`.
    ///
    ///     static let surface = Color(light: .white, dark: AppColors.offBlack)
    ///
    /// It is a Color, so it goes anywhere a Color goes: in a `Style`, on a
    /// control, on a page. The half in force is chosen as the colour is put on
    /// a node, and a view that asked is rebuilt when the system theme changes -
    /// so a `Style` written with one is right in both.
    public init(light: Color, dark: Color) {
        self.light = light.light
        self.dark = dark.light
    }

    /// The channels themselves, and the ones for dark mode when there are any.
    init(_ light: Rgba, dark: Rgba? = nil) {
        self.light = light
        self.dark = dark
    }

    /// A colour from hex - "#RGB", "#ARGB", "#RRGGBB" or "#AARRGGBB".
    /// MAUI: Color.FromArgb.
    ///
    /// The same thing as `Color("#512BD4")`, under the name someone coming
    /// from MAUI will look for. Traps on anything that is not hex, as that
    /// initializer does.
    public static func fromArgb(_ hex: String) -> Color {
        Color(hex)
    }

    /// Red, green and blue, each 0-255, fully opaque.
    /// MAUI: Color.FromRgb - whose own overload takes 0-1 floats as well.
    ///
    ///     Color.fromRgb(81, 43, 212)
    ///
    /// A value outside 0-255 is held to the range rather than refused.
    public static func fromRgb(_ red: Int, _ green: Int, _ blue: Int) -> Color {
        fromRgba(red, green, blue, 255)
    }

    /// The same with an alpha, 0 being invisible and 255 opaque.
    /// MAUI: Color.FromRgba.
    public static func fromRgba(_ red: Int, _ green: Int, _ blue: Int, _ alpha: Int) -> Color {
        Color(Rgba(
            red: channel(red),
            green: channel(green),
            blue: channel(blue),
            alpha: channel(alpha)))
    }

    /// The half in force, which is the light one unless the system is dark and
    /// this colour was written with a second.
    ///
    /// Reading the theme here is what records the dependency: the read lands
    /// against whichever view is being built, so a theme change rebuilds that
    /// view and leaves the rest alone.
    var resolved: Rgba {
        guard let dark = dark else { return light }

        return StandardEnvironment.app.requestedTheme == .dark ? dark : light
    }

    /// The four bytes of the half in force, under the wire's own colour tag -
    /// which colours have because they are the value a tree carries most of and
    /// the cheapest to say exactly. Nothing on the far side parses a colour or
    /// has to know what one may look like.
    var propValue: PropValue {
        let channels = resolved

        return .color(
            red: channels.red,
            green: channels.green,
            blue: channels.blue,
            alpha: channels.alpha)
    }

    // A colour crosses as its four bytes wherever it crosses, so there is no
    // way back to "#AARRGGBB" here and there should not be one. Reading hex is
    // how a colour is WRITTEN in source - that half is below.

    // MARK: - Reading hex

    /// The channels a hex string names, or nil when it names none.
    ///
    /// Four lengths, exactly MAUI's: three and four digits are the shorthand
    /// where each digit stands for both of its pair, six and eight the full
    /// form. Alpha comes FIRST in the four- and eight-digit forms, which is
    /// what ARGB means.
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
// The set from MAUI's `Colors` class that comes up in practice. Anything else is
// one `Color.fromArgb("#…")` away - MAUI's full list is CSS's, and repeating all
// 140 of them here would be noise.

extension Color {
    /// Nothing at all. MAUI: Colors.Transparent, #00FFFFFF.
    public static let transparent = Color("#00FFFFFF")

    /// MAUI: Colors.Black, #000000.
    public static let black = Color("#000000")

    /// MAUI: Colors.White, #FFFFFF.
    public static let white = Color("#FFFFFF")

    /// MAUI: Colors.Gray, #808080.
    public static let gray = Color("#808080")

    /// MAUI: Colors.LightGray, #D3D3D3.
    public static let lightGray = Color("#D3D3D3")

    /// Darker than Gray despite the name - CSS's, and MAUI keeps it.
    /// MAUI: Colors.DarkGray, #A9A9A9.
    public static let darkGray = Color("#A9A9A9")

    /// MAUI: Colors.DimGray, #696969.
    public static let dimGray = Color("#696969")

    /// MAUI: Colors.Silver, #C0C0C0.
    public static let silver = Color("#C0C0C0")

    /// MAUI: Colors.WhiteSmoke, #F5F5F5.
    public static let whiteSmoke = Color("#F5F5F5")

    /// MAUI: Colors.Red, #FF0000.
    public static let red = Color("#FF0000")

    /// MAUI: Colors.Firebrick, #B22222.
    public static let firebrick = Color("#B22222")

    /// MAUI: Colors.Tomato, #FF6347.
    public static let tomato = Color("#FF6347")

    /// MAUI: Colors.Orange, #FFA500.
    public static let orange = Color("#FFA500")

    /// MAUI: Colors.Gold, #FFD700.
    public static let gold = Color("#FFD700")

    /// MAUI: Colors.Yellow, #FFFF00.
    public static let yellow = Color("#FFFF00")

    /// The dark one. MAUI: Colors.Green, #008000 - `.lime` is #00FF00.
    public static let green = Color("#008000")

    /// MAUI: Colors.Lime, #00FF00.
    public static let lime = Color("#00FF00")

    /// MAUI: Colors.ForestGreen, #228B22.
    public static let forestGreen = Color("#228B22")

    /// MAUI: Colors.Teal, #008080.
    public static let teal = Color("#008080")

    /// MAUI: Colors.Cyan, #00FFFF.
    public static let cyan = Color("#00FFFF")

    /// MAUI: Colors.Blue, #0000FF.
    public static let blue = Color("#0000FF")

    /// MAUI: Colors.Navy, #000080.
    public static let navy = Color("#000080")

    /// MAUI: Colors.DodgerBlue, #1E90FF.
    public static let dodgerBlue = Color("#1E90FF")

    /// MAUI: Colors.CornflowerBlue, #6495ED.
    public static let cornflowerBlue = Color("#6495ED")

    /// MAUI: Colors.SteelBlue, #4682B4.
    public static let steelBlue = Color("#4682B4")

    /// MAUI: Colors.LightBlue, #ADD8E6.
    public static let lightBlue = Color("#ADD8E6")

    /// MAUI: Colors.Purple, #800080.
    public static let purple = Color("#800080")

    /// MAUI: Colors.Indigo, #4B0082.
    public static let indigo = Color("#4B0082")

    /// MAUI: Colors.Violet, #EE82EE.
    public static let violet = Color("#EE82EE")

    /// MAUI: Colors.Magenta, #FF00FF.
    public static let magenta = Color("#FF00FF")

    /// MAUI: Colors.Pink, #FFC0CB.
    public static let pink = Color("#FFC0CB")

    /// MAUI: Colors.Brown, #A52A2A.
    public static let brown = Color("#A52A2A")

    /// MAUI: Colors.Maroon, #800000.
    public static let maroon = Color("#800000")

    /// MAUI: Colors.Olive, #808000.
    public static let olive = Color("#808000")
}
