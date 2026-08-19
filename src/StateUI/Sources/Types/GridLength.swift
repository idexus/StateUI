// MAUI: GridLength.

/// How much room one grid row or column takes. MAUI: GridLength.
///
///     Grid { … }
///         .rowDefinitions(.auto, .star, .star(2), .absolute(100))
///
/// The three kinds MAUI has: `Auto` fits the content, `Star` shares what is left
/// in proportion, and an absolute length is device-independent units. The stars
/// are settled last, out of whatever the auto and absolute rows leave.
///
/// It travels as the two PARTS it is - which kind, then the number that kind
/// takes - and a list of them as a list of those.
public enum GridLength: Sendable {
    /// As much as the content needs, and no more.
    /// MAUI: GridLength.Auto, `Auto` in XAML.
    case auto

    /// A share of what is left over, in proportion to the other stars: two
    /// columns of `.star` and `.star(2)` split it one to two.
    /// MAUI: GridLength.Star, `2*` in XAML.
    case star(Double)

    /// Exactly this many device units, whatever the content measures at.
    /// MAUI: GridUnitType.Absolute, a bare `100` in XAML.
    case absolute(Double)

    /// One share of what is left - MAUI's `GridLength.Star`, and `*` in XAML.
    public static var star: GridLength { .star(1) }

    /// Which of MAUI's three kinds a length is, as the number that crosses - a
    /// closed vocabulary, so it rides its member rather than a spelling.
    ///
    /// MAUI: GridUnitType. Mirrored by `SwiftGridLengthKind`, which maps each
    /// member onto the GridUnitType of the same name, so a MAUI renumbering
    /// cannot reach this wire.
    enum Kind: Int32, Sendable {
        case absolute = 0
        case star = 1
        case auto = 2
    }

    /// The kind, then the number that kind takes.
    ///
    /// `Auto` carries 1 rather than nothing, because that is what MAUI's own
    /// `GridLength.Auto` carries - and a `GridLength` compares by both fields,
    /// so a 0 there would build a length EQUAL to no static MAUI declares.
    var propValue: PropValue {
        switch self {
        case .auto:
            return .values([.enumeration(Kind.auto.rawValue), .number(1)])
        case .star(let share):
            return .values([.enumeration(Kind.star.rawValue), .number(share)])
        case .absolute(let length):
            return .values([.enumeration(Kind.absolute.rawValue), .number(length)])
        }
    }
}

extension Array where Element == GridLength {
    /// The definitions, each as its own two parts - so the LIST itself says
    /// how many rows or columns there are.
    var propValue: PropValue {
        .values(map { $0.propValue })
    }
}
