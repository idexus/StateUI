// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A color, held as four 8-bit sRGB channels, and as a pair where the two
// themes want different colors.
// Design: docs/design/types/color-and-theme.md#four-channels

/// A color.
///
///     Color(hex: 0x512BD4)
///     Color.cornflowerBlue
///     Color(light: .white, dark: .black)
///
/// Written as a hex number or by name, and as a pair where the two themes want
/// different colors - `Color(light:dark:)` is one value that goes wherever a
/// color goes. Held as four 8-bit channels, so two spellings of one color
/// are equal and hash alike.
public struct Color: Hashable, Sendable, HostRepresentable {
    /// The four sRGB channels of one color, 0-255 each.
    struct Rgba: Hashable, Sendable {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
        let alpha: UInt8
    }

    /// The color in force unless the theme is dark and there is a dark half.
    let light: Rgba

    /// The dark theme's half of a pair; the differ picks the half in force.
    /// Design: docs/design/types/color-and-theme.md#a-pair-for-each-theme
    let dark: Rgba?

    /// The halves that are the accent in force rather than channels, each keeping only its alpha - the differ
    /// reads the accent as the view wearing it is built.
    let accentHalves: Halves

    /// The halves of a color: the light one, and the dark one of a pair.
    struct Halves: OptionSet, Hashable, Sendable {
        let rawValue: UInt8
        static let light = Halves(rawValue: 1)
        static let dark = Halves(rawValue: 2)
    }

    /// Whether this is the accent in force, whole - no pair around it.
    var isAccent: Bool { dark == nil && accentHalves.contains(.light) }

    /// A color from its hex number, the digits a design gives - `0xRRGGBB` - and how opaque it is, from 0,
    /// invisible, to 1, opaque - the default.
    ///
    ///     Color(hex: 0x512BD4)
    ///     Color(hex: 0x000000, opacity: 0.4)
    ///
    /// Six digits: a number past `0xFFFFFF` stops the program with a message, since what is not seen through is
    /// `opacity`. A color's name is `Color.red` and its kin.
    public init(hex: UInt32, opacity: Double = 1) {
        precondition(
            hex <= 0xFFFFFF,
            "0x\(String(hex, radix: 16, uppercase: true)) is not a color's hex number: write six digits, 0xRRGGBB, "
                + "and the alpha as opacity:")
        self.init(Rgba(
            red: UInt8(hex >> 16 & 0xFF), green: UInt8(hex >> 8 & 0xFF), blue: UInt8(hex & 0xFF),
            alpha: Color.alpha(of: opacity)))
    }

    /// A color read from text that data holds - "#RGB", "#ARGB", "#RRGGBB" or "#AARRGGBB", with or without the
    /// leading `#`, the alpha, when it is written, first - or nil where the text is not one.
    ///
    ///     let brand = Color(parsing: theme["brand"] ?? "") ?? .accent
    ///
    /// A color written in code is `Color(hex:)`.
    public init?(parsing text: String) {
        guard let parsed = Color.channels(of: text) else { return nil }
        self.init(parsed)
    }

    /// The same color named twice, once for each theme.
    ///
    ///     static let surface = Color(light: .white, dark: AppColors.offBlack)
    ///
    /// It goes anywhere a color goes - a `Style`, a control, a page's background,
    /// a state - and follows the system theme wherever it is written.
    ///
    /// Design: docs/design/types/color-and-theme.md#a-pair-for-each-theme
    public init(light: Color, dark: Color) {
        // A pair handed as a half gives the half of that theme; the accent stays the accent.
        self.light = light.light
        self.dark = dark.dark ?? dark.light
        var halves: Halves = []
        if light.accentHalves.contains(.light) { halves.insert(.light) }
        if dark.accentHalves.contains(dark.dark == nil ? .light : .dark) { halves.insert(.dark) }
        self.accentHalves = halves
    }

    /// The channels themselves, and the ones for dark mode when there are any.
    init(_ light: Rgba, dark: Rgba? = nil, accentHalves: Halves = []) {
        self.light = light
        self.dark = dark
        self.accentHalves = accentHalves
    }

    /// The accent in force, let through to `alpha`.
    private init(accentAlpha alpha: UInt8) {
        light = Color.accentHalf(alpha)
        dark = nil
        accentHalves = .light
    }

    /// The channels an accent half keeps: its alpha alone.
    private static func accentHalf(_ alpha: UInt8) -> Rgba { Rgba(red: 0, green: 0, blue: 0, alpha: alpha) }

    /// The accent in force: the one the user chose for the system - or, on a
    /// platform with none, the application's own tint - read as the view
    /// wearing it is built, so a change in the system's settings builds again
    /// exactly the views wearing it, in a style too.
    ///
    ///     Switch($on).tint(.accent)
    ///     Text("Saved").textColor(.accent.opacity(0.7))
    public static let accent = Color(accentAlpha: 255)

    /// A color from its channels: red, green and blue, each 0-255, and an
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

    /// The color let through: its alpha scaled by `fraction`, from 0,
    /// invisible, to 1, as it is - in both halves of a pair.
    ///
    ///     accent.opacity(0.15)   // a light wash of it
    public func opacity(_ fraction: Double) -> Color {
        let kept = Color.fraction(fraction)
        func scaled(_ channels: Rgba) -> Rgba {
            Rgba(red: channels.red, green: channels.green, blue: channels.blue,
                 alpha: UInt8((Double(channels.alpha) * kept).rounded()))
        }
        return Color(scaled(light), dark: dark.map(scaled), accentHalves: accentHalves)
    }

    /// A share held to 0-1, nothing for what is no number.
    private static func fraction(_ value: Double) -> Double {
        value.isNaN || value < 0 ? 0 : (value > 1 ? 1 : value)
    }

    /// The alpha channel of how opaque a color is, from 0 to 1.
    private static func alpha(of opacity: Double) -> UInt8 {
        UInt8((255 * fraction(opacity)).rounded())
    }

    /// Four bytes under the color kind, both halves as a themed pair, or the
    /// accent in force as the system's color the differ resolves.
    public var propValue: PropValue {
        let lightHalf = accentHalves.contains(.light) ? .systemColor(0, alpha: light.alpha) : Color.tagged(light)
        guard let dark else { return lightHalf }

        let darkHalf = accentHalves.contains(.dark) ? .systemColor(0, alpha: dark.alpha) : Color.tagged(dark)
        return .themed(light: lightHalf, dark: darkHalf)
    }

    /// A color back: four channels, or a pair of them - nil for anything
    /// else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        switch propValue {
        case .systemColor(0, let alpha):
            self.init(accentAlpha: alpha)
        case .color(let red, let green, let blue, let alpha):
            self.init(Rgba(red: red, green: green, blue: blue, alpha: alpha))

        case .themed(let lightHalf, let darkHalf):
            guard let light = Color(propValue: lightHalf), let dark = Color(propValue: darkHalf),
                  light.dark == nil, dark.dark == nil
            else { return nil }

            self.init(light: light, dark: dark)

        default:
            return nil
        }
    }

    /// Four channels under the color tag.
    private static func tagged(_ channels: Rgba) -> PropValue {
        .color(red: channels.red, green: channels.green, blue: channels.blue, alpha: channels.alpha)
    }

    // MARK: - Reading hex

    /// The channels a hex string names, or nil. Three and four digits are the
    /// shorthand, each digit standing for both of its pair; alpha comes first
    /// in four and eight digits.
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
// The common ones, with their CSS names and values.

extension Color {
    /// Nothing at all, #00FFFFFF.
    public static let transparent = Color(hex: 0xFFFFFF, opacity: 0)

    /// Black, #000000.
    public static let black = Color(hex: 0x000000)

    /// White, #FFFFFF.
    public static let white = Color(hex: 0xFFFFFF)

    /// Gray, #808080.
    public static let gray = Color(hex: 0x808080)

    /// Light gray, #D3D3D3.
    public static let lightGray = Color(hex: 0xD3D3D3)

    /// Dark gray, #A9A9A9 - lighter than `.gray` despite the CSS name.
    public static let darkGray = Color(hex: 0xA9A9A9)

    /// Dim gray, #696969.
    public static let dimGray = Color(hex: 0x696969)

    /// Silver, #C0C0C0.
    public static let silver = Color(hex: 0xC0C0C0)

    /// White smoke, #F5F5F5.
    public static let whiteSmoke = Color(hex: 0xF5F5F5)

    /// Red, #FF0000.
    public static let red = Color(hex: 0xFF0000)

    /// Firebrick, #B22222.
    public static let firebrick = Color(hex: 0xB22222)

    /// Tomato, #FF6347.
    public static let tomato = Color(hex: 0xFF6347)

    /// Orange, #FFA500.
    public static let orange = Color(hex: 0xFFA500)

    /// Gold, #FFD700.
    public static let gold = Color(hex: 0xFFD700)

    /// Yellow, #FFFF00.
    public static let yellow = Color(hex: 0xFFFF00)

    /// Green, the dark one: #008000 - `.lime` is #00FF00.
    public static let green = Color(hex: 0x008000)

    /// Lime, #00FF00.
    public static let lime = Color(hex: 0x00FF00)

    /// Forest green, #228B22.
    public static let forestGreen = Color(hex: 0x228B22)

    /// Teal, #008080.
    public static let teal = Color(hex: 0x008080)

    /// Cyan, #00FFFF.
    public static let cyan = Color(hex: 0x00FFFF)

    /// Blue, #0000FF.
    public static let blue = Color(hex: 0x0000FF)

    /// Navy, #000080.
    public static let navy = Color(hex: 0x000080)

    /// Dodger blue, #1E90FF.
    public static let dodgerBlue = Color(hex: 0x1E90FF)

    /// Cornflower blue, #6495ED.
    public static let cornflowerBlue = Color(hex: 0x6495ED)

    /// Steel blue, #4682B4.
    public static let steelBlue = Color(hex: 0x4682B4)

    /// Light blue, #ADD8E6.
    public static let lightBlue = Color(hex: 0xADD8E6)

    /// Purple, #800080.
    public static let purple = Color(hex: 0x800080)

    /// Indigo, #4B0082.
    public static let indigo = Color(hex: 0x4B0082)

    /// Violet, #EE82EE.
    public static let violet = Color(hex: 0xEE82EE)

    /// Magenta, #FF00FF.
    public static let magenta = Color(hex: 0xFF00FF)

    /// Pink, #FFC0CB.
    public static let pink = Color(hex: 0xFFC0CB)

    /// Brown, #A52A2A.
    public static let brown = Color(hex: 0xA52A2A)

    /// Maroon, #800000.
    public static let maroon = Color(hex: 0x800000)

    /// Olive, #808000.
    public static let olive = Color(hex: 0x808000)
}
