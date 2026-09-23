// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The closed vocabularies a property takes. Each case crosses as a number
// StateUI owns, in declaration order from 0 and written out: append a case,
// never insert one. A flag set's bits run `1 << 0` upwards the same way.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Where a view sits in the space its layout gives it - what
/// `.horizontalAlignment` and `.verticalAlignment` take.
public enum Alignment: Int32, Sendable {
    /// At the near edge - the left, or the top - taking only the room it needs.
    case start = 0

    /// In the middle, taking only the room it needs.
    case center = 1

    /// At the far edge, taking only the room it needs.
    case end = 2

    /// Taking all of it. The default.
    case fill = 3
}

/// Whether text is drawn bold, italic, or both.
///
///     Label("Total").fontAttributes(.bold)
///     Label("Total").fontAttributes([.bold, .italic])
///
/// Only the weight and the slant: the family is `.fontFamily` and the size
/// `.fontSize`, each its own modifier as it is its own property.
public struct FontAttributes: OptionSet, Sendable {
    /// The flag bits.
    public let rawValue: Int32

    /// From the raw bits. `.bold`, `.italic` and `[.bold, .italic]` are the
    /// ordinary way in.
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// Neither bold nor italic.
    public static let none = FontAttributes([])

    /// Drawn bold.
    public static let bold = FontAttributes(rawValue: 1 << 0)

    /// Drawn italic.
    public static let italic = FontAttributes(rawValue: 1 << 1)
}

/// Where text sits inside the space its own control was given.
///
/// What `.horizontalTextAlignment` and `.verticalTextAlignment` take. NOT
/// `.horizontalAlignment`, which moves the whole control inside its layout: a
/// label centred with this one still occupies the same box.
public enum TextAlignment: Int32, Sendable {
    /// Against the near edge - the left in a left-to-right language.
    case start = 0

    /// Centred.
    case center = 1

    /// Against the far edge.
    case end = 2
}

/// What text does when it will not fit on one line - wrap, or be cut short
/// with an ellipsis.
///
/// The truncating cases need the control to be BOUNDED to show anything: a
/// label free to grow never runs out of room, so nothing is ever cut.
public enum LineBreak: Int32, Sendable {
    /// One line, whatever it costs.
    case noWrap = 0

    /// Wraps at spaces. The default for a Label.
    case wordWrap = 1

    /// Wraps mid-word where a word does not fit.
    case characterWrap = 2

    /// One line, cut at the START, with an ellipsis there.
    case headTruncation = 3

    /// One line, cut at the END, with an ellipsis there.
    case tailTruncation = 4

    /// One line, cut in the MIDDLE - which keeps both ends readable, as a file
    /// path wants.
    case middleTruncation = 5
}

/// The lines drawn through or under text.
///
///     Label("$40").textDecorations(.strikethrough)
public struct TextDecorations: OptionSet, Sendable {
    /// The flag bits.
    public let rawValue: Int32

    /// From the raw bits. `.underline`, `.strikethrough` and both together are
    /// the ordinary way in.
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// Plain text.
    public static let none = TextDecorations([])

    /// A line under the text.
    public static let underline = TextDecorations(rawValue: 1 << 0)

    /// A line through it.
    public static let strikethrough = TextDecorations(rawValue: 1 << 1)
}

/// Whether the text is drawn as written, or in one case throughout.
///
/// The letters the user sees change; the value behind them does not - a
/// `TextField` set to `.uppercase` still reports what was typed, so this is a
/// look rather than an edit.
public enum TextCase: Int32, Sendable {
    /// As written.
    case none = 0

    /// As the platform sees fit, which everywhere is as written.
    case `default` = 1

    /// all in lower case.
    case lowercase = 2

    /// ALL IN UPPER CASE - a heading, a button's caption.
    case uppercase = 3
}

/// What a text input is for, which picks the on-screen keyboard the platform
/// offers.
public enum InputPurpose: Int32, Sendable {
    /// Whatever the platform offers, with its own correction and capitalization.
    case `default` = 0

    /// The default one with no correction, capitalization or suggestions.
    case plain = 1

    /// Set up for conversation - emoji, and no autocorrection getting in the way.
    case chat = 2

    /// With @ and . to hand.
    case email = 3

    /// Digits only.
    case numeric = 4

    /// A phone dialler's keypad.
    case telephone = 5

    /// General text, with the platform's spellcheck and capitalization.
    case text = 6

    /// With / and .com to hand.
    case url = 7
}

/// The label on the keyboard's return key.
public enum ReturnKey: Int32, Sendable {
    /// Whatever the platform calls it.
    case `default` = 0

    /// "Done".
    case done = 1

    /// "Go".
    case go = 2

    /// "Next", for a field with another after it.
    case next = 3

    /// "Search".
    case search = 4

    /// "Send".
    case send = 5
}

/// Which ways a `ScrollView` scrolls.
public enum ScrollOrientation: Int32, Sendable {
    /// Up and down. The default.
    case vertical = 0

    /// Sideways.
    case horizontal = 1

    /// Both at once.
    case both = 2

    /// Neither - which is how a ScrollView is stopped from scrolling without
    /// being replaced.
    case neither = 3
}

/// What a map pin stands for - what `.type` takes, and what decides the icon
/// the platform draws.
public enum PinType: Int32, Sendable {
    /// Somewhere on the map, with no more said. The default.
    case generic = 0

    /// A place - a shop, a station, a landmark.
    case place = 1

    /// One the user saved.
    case savedPin = 2

    /// One a search turned up.
    case searchResult = 3
}

/// How a picture or a shape fills the room it was given, when the two are not
/// the same shape - what `.aspect` takes on an `Image` and on a shape alike.
///
/// Something has to give: the space, the edges, or the proportions.
public enum Aspect: Int32, Sendable {
    /// Fits it all in, keeping the proportions - so there may be space at the
    /// sides. The default.
    case fit = 0

    /// Covers the room, keeping the proportions - so the edges may be cut off.
    case fill = 1

    /// Fills the room, proportions and all - so it may be stretched.
    case stretch = 2

    /// Drawn at its own size, in the middle.
    case center = 3
}

/// Which way a view lays its content out, and which edge it starts from -
/// what `.layoutDirection` takes.
///
/// The point of it is a language written right to left: a view told
/// `.rightToLeft` mirrors its layout, so a stack fills from the right and a
/// label's natural alignment moves with it.
public enum LayoutDirection: Int32, Sendable {
    /// Whatever the view above says, which is how a view inherits the
    /// application's. The default.
    case inherited = 0

    /// Left to right, whatever the view above says.
    case leftToRight = 1

    /// Right to left, whatever the view above says.
    case rightToLeft = 2
}

/// How deep a heading is - what `.accessibilityHeadingLevel` takes.
///
/// A user who cannot see the page moves through it by its headings, and the
/// level is what tells them whether the next one starts a section or sits
/// inside the one they are in.
public enum HeadingLevel: Int32, Sendable {
    /// Ordinary content, however large it happens to be drawn. The default.
    case none = 0

    /// What the page itself is about - one of these, at the top.
    case level1 = 1

    /// A section of the page.
    case level2 = 2

    /// A part of a section.
    case level3 = 3

    /// A part of that.
    case level4 = 4

    /// Deeper again.
    case level5 = 5

    /// Deeper again.
    case level6 = 6

    /// Deeper again.
    case level7 = 7

    /// Deeper again.
    case level8 = 8

    /// The deepest a heading goes.
    case level9 = 9
}

/// When the scroll bars are drawn - what `.verticalScrollBarVisibility` and
/// `.horizontalScrollBarVisibility` take.
public enum ScrollBarVisibility: Int32, Sendable {
    /// As the platform sees fit.
    case `default` = 0

    /// Always shown.
    case always = 1

    /// Never shown, though it still scrolls.
    case never = 2
}

/// The outline a Border draws, and the shape its own background is painted to
/// - which is where a rounded corner comes from on anything but a Button or a
/// ColorBox. What `.shape` takes.
///
///     Border { … }.shape(.roundedRectangle(12))
public enum BorderShape: Equatable, Sendable, HostRepresentable {
    /// Square corners.
    case rectangle

    /// Rounded corners, by this many device units.
    case roundedRectangle(Double)

    /// An oval filling the border's bounds.
    case ellipse

    /// Which shape this is, as the number that crosses ahead of its parts.
    /// Design: docs/design/types/vocabularies.md#a-kind-first
    enum Kind: Int32, Sendable {
        case rectangle = 0
        case roundedRectangle = 1
        case ellipse = 2
    }

    /// The kind, then what that kind is made of.
    public var propValue: PropValue {
        switch self {
        case .rectangle:
            return .values([.enumeration(Kind.rectangle.rawValue)])
        case .roundedRectangle(let radius):
            return .values([.enumeration(Kind.roundedRectangle.rawValue), .number(radius)])
        case .ellipse:
            return .values([.enumeration(Kind.ellipse.rawValue)])
        }
    }

    /// The shape a kind and its parts name - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .values(let parts) = propValue, case .enumeration(let number)? = parts.first,
              let kind = Kind(rawValue: number)
        else { return nil }

        switch (kind, parts.count) {
        case (.rectangle, 1):
            self = .rectangle
        case (.roundedRectangle, 2):
            guard case .number(let radius) = parts[1] else { return nil }
            self = .roundedRectangle(radius)
        case (.ellipse, 1):
            self = .ellipse
        default:
            return nil
        }
    }
}

/// Which parts of a child's bounds an AbsoluteLayout reads as fractions rather
/// than as device units.
///
///     .absoluteLayoutBounds(Rect(0.5, 0, 0.5, 1))
///     .absoluteLayoutProportions(.all)
///
/// A fraction is of the layout's size, so 0.5 is half of it however big it
/// turns out to be.
public struct AbsoluteLayoutProportions: OptionSet, Sendable {
    /// The flag bits.
    public let rawValue: Int32

    /// From the raw bits. The members below are the ordinary way in.
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// Every number is device units. The default.
    public static let none = AbsoluteLayoutProportions([])

    /// The position across as a fraction.
    public static let x = AbsoluteLayoutProportions(rawValue: 1 << 0)

    /// The position down as a fraction.
    public static let y = AbsoluteLayoutProportions(rawValue: 1 << 1)

    /// Both edges as fractions, the size still in device units.
    public static let position: AbsoluteLayoutProportions = [.x, .y]

    /// The width as a fraction.
    public static let width = AbsoluteLayoutProportions(rawValue: 1 << 2)

    /// The height as a fraction.
    public static let height = AbsoluteLayoutProportions(rawValue: 1 << 3)

    /// Both lengths as fractions, the position still in device units.
    public static let size: AbsoluteLayoutProportions = [.width, .height]

    /// All four as fractions.
    public static let all: AbsoluteLayoutProportions = [.position, .size]
}

/// What a swipe reveals: buttons to tap, or one act carried out by the swipe
/// itself.
public enum SwipeMode: Int32, Sendable {
    /// The items appear and wait to be tapped. The default.
    case reveal = 0

    /// A full swipe runs the first item, with no tap at all.
    case execute = 1
}

/// What the open items do once one of them has run.
public enum SwipeBehaviorOnInvoked: Int32, Sendable {
    /// Closed after a reveal, left open after an execute. The default.
    case auto = 0

    /// Always closed.
    case close = 1

    /// Always left open.
    case remainOpen = 2
}

/// How the end of an open line is drawn.
public enum LineCap: Int32, Sendable {
    /// Cut off square at the end point. The default.
    case flat = 0

    /// A half-circle beyond the end point, so the line looks rounded off.
    case round = 1

    /// A square beyond the end point - the same shape as `.flat`, half a stroke
    /// further along.
    case square = 2
}

/// How two segments of a line meet.
public enum LineJoin: Int32, Sendable {
    /// A sharp corner, as far out as the two edges reach. The default.
    case miter = 0

    /// The corner cut off flat.
    case bevel = 1

    /// The corner rounded.
    case round = 2
}

/// Which parts of a self-crossing outline count as inside it.
public enum FillRule: Int32, Sendable {
    /// Inside where a ray out of the shape crosses an odd number of edges - so
    /// the middle of a five-pointed star is a hole. The default.
    case evenOdd = 0

    /// Inside where the edges crossed do not cancel out by direction - so the
    /// middle of a star is filled.
    case nonzero = 1
}

/// What one dot of a PositionIndicator is drawn as.
public enum IndicatorShape: Int32, Sendable {
    /// A dot. The default.
    case circle = 0

    /// A square.
    case square = 1
}

/// Where a toolbar item goes in the platform's native action surface.
public enum ToolbarItemPlacement: Int32, Sendable {
    /// Wherever the platform normally puts an item.
    case automatic = 0

    /// On the bar itself, where it can be chosen straight away.
    case bar = 1

    /// Behind the native overflow menu.
    case overflow = 2
}

/// What one edge of a layout stays clear of on the screen's unsafe strip -
/// the notch, the bars, the on-screen keyboard.
///
/// Only iOS has such a strip; the other platforms ignore this. A layout there
/// defaults to `.container` - see `avoidsSafeArea`.
public enum SafeArea: Int32, Sendable {
    /// Edge to edge: content may run under the notch, the bars and the
    /// keyboard.
    case none = 0

    /// Clear of the on-screen keyboard, under everything else.
    case keyboard = 1

    /// Clear of the bars and the notch, under the keyboard. What an iOS
    /// layout does when nothing is said.
    case container = 2

    /// Clear of everything - bars, notch and keyboard alike.
    case all = 3
}

/// What each edge of a layout stays clear of - one answer for all four, or one
/// for each. What `.avoidsSafeArea` takes.
public enum SafeAreaEdges: Equatable, Sendable, HostRepresentable {
    /// The same answer for all four edges.
    case uniform(SafeArea)

    /// Each edge's own: left, top, right, bottom.
    case edges(left: SafeArea, top: SafeArea, right: SafeArea, bottom: SafeArea)

    /// One member, or the four in order, each a value of its own.
    public var propValue: PropValue {
        switch self {
        case .uniform(let area):
            return area.propValue
        case .edges(let left, let top, let right, let bottom):
            return .values([left.propValue, top.propValue, right.propValue, bottom.propValue])
        }
    }

    /// The answer back: one member, or four in order - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        if let area = SafeArea(propValue: propValue) {
            self = .uniform(area)
            return
        }

        guard let values = propValue.values, values.count == 4,
              let left = SafeArea(propValue: values[0]), let top = SafeArea(propValue: values[1]),
              let right = SafeArea(propValue: values[2]), let bottom = SafeArea(propValue: values[3])
        else { return nil }

        self = .edges(left: left, top: top, right: right, bottom: bottom)
    }
}

// MARK: - The choices a state can carry
// Design: docs/design/types/vocabularies.md#choices-a-state-can-carry

extension AbsoluteLayoutProportions: StateChoice {}
extension Aspect: StateChoice {}
extension FillRule: StateChoice {}
extension LayoutDirection: StateChoice {}
extension FontAttributes: StateChoice {}
extension IconPosition: StateChoice {}
extension IndicatorShape: StateChoice {}
extension InputPurpose: StateChoice {}
extension Alignment: StateChoice {}
extension LineBreak: StateChoice {}
extension LineCap: StateChoice {}
extension LineJoin: StateChoice {}
extension ReturnKey: StateChoice {}
extension SafeArea: StateChoice {}
extension HeadingLevel: StateChoice {}
extension ScrollBarVisibility: StateChoice {}
extension ScrollOrientation: StateChoice {}
extension TextAlignment: StateChoice {}
extension TextDecorations: StateChoice {}
extension TextCase: StateChoice {}

// MARK: - The values a member holds, each crossing as its member's number

extension AbsoluteLayoutProportions: HostRepresentable {}
extension Alignment: HostRepresentable {}
extension Aspect: HostRepresentable {}
extension FillRule: HostRepresentable {}
extension FontAttributes: HostRepresentable {}
extension HeadingLevel: HostRepresentable {}
extension IndicatorShape: HostRepresentable {}
extension InputPurpose: HostRepresentable {}
extension LayoutDirection: HostRepresentable {}
extension LineBreak: HostRepresentable {}
extension LineCap: HostRepresentable {}
extension LineJoin: HostRepresentable {}
extension PinType: HostRepresentable {}
extension ReturnKey: HostRepresentable {}
extension SafeArea: HostRepresentable {}
extension ScrollBarVisibility: HostRepresentable {}
extension ScrollOrientation: HostRepresentable {}
extension SwipeBehaviorOnInvoked: HostRepresentable {}
extension SwipeMode: HostRepresentable {}
extension TextAlignment: HostRepresentable {}
extension TextCase: HostRepresentable {}
extension TextDecorations: HostRepresentable {}
extension ToolbarItemPlacement: HostRepresentable {}
