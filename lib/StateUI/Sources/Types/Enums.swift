// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The closed vocabularies a property takes.
//
// Each case travels on the wire as a number rather than a spelling, and that
// number belongs to StateUI's wire contract, never to a toolkit. A host maps
// each case onto its own toolkit's equivalent: what a case promises is what its
// `///` says, and the number is only how it crosses.
//
// Declaration order from 0, and it has no exceptions. The numbers are written
// out rather than left to the compiler because they are a wire contract: a case
// inserted in the middle would silently shift every case after it - every
// property on the wire then reading as a different member, with nothing
// failing anywhere - and seeing the numbers is what makes that hard to do by
// accident. `WireVocabularyTests` holds every case to a number written out.
// Appending a case is free; inserting or reordering one is not.
//
// The flag sets (FontAttributes, TextDecorations, AbsoluteLayoutFlags) are
// OptionSets, so both `.bold` and `[.bold, .italic]` work. Their bits are ours
// by the same rule - `1 << 0` upwards in declaration order - and a composite
// is written as the OR of its parts, so a bit set travels as nothing more than
// its bits.

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

    var propValue: PropValue { .enumeration(rawValue) }
}

/// Whether text is drawn bold, italic, or both - a flag set, with bits of this
/// library's own.
///
///     Label("Total").fontAttributes(.bold)
///     Label("Total").fontAttributes([.bold, .italic])
///
/// Only the weight and the slant: the family is `.fontFamily` and the size
/// `.fontSize`, each its own modifier as it is its own property.
public struct FontAttributes: OptionSet, Sendable {
    /// The bits, as an OptionSet keeps them - this library's own, see the head
    /// of this file.
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

    var propValue: PropValue { .enumeration(rawValue) }
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

    var propValue: PropValue { .enumeration(rawValue) }
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

    var propValue: PropValue { .enumeration(rawValue) }
}

/// The lines drawn through or under text - a flag set, with bits of this
/// library's own.
///
///     Label("$40").textDecorations(.strikethrough)
public struct TextDecorations: OptionSet, Sendable {
    /// The bits, as an OptionSet keeps them - this library's own, see the head
    /// of this file.
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

    var propValue: PropValue { .enumeration(rawValue) }
}

/// Whether the text is drawn as written, or in one case throughout.
///
/// The letters the reader SEES change; the value behind them does not - an
/// `TextField` set to `.uppercase` still reports what was typed, so this is a look
/// rather than an edit.
public enum TextCase: Int32, Sendable {
    /// As written.
    case none = 0

    /// As the platform sees fit, which everywhere is as written.
    case `default` = 1

    /// all in lower case.
    case lowercase = 2

    /// ALL IN UPPER CASE - a heading, a button's caption.
    case uppercase = 3

    var propValue: PropValue { .enumeration(rawValue) }
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

    var propValue: PropValue { .enumeration(rawValue) }
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

    var propValue: PropValue { .enumeration(rawValue) }
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

    var propValue: PropValue { .enumeration(rawValue) }
}

/// What a map pin stands for - what `.type` takes, and what decides the icon
/// the platform draws.
public enum PinType: Int32, Sendable {
    /// Somewhere on the map, with no more said. The default.
    case generic = 0

    /// A place - a shop, a station, a landmark.
    case place = 1

    /// One the reader saved.
    case savedPin = 2

    /// One a search turned up.
    case searchResult = 3

    var propValue: PropValue { .enumeration(rawValue) }
}

/// How a picture fills the space an `Image` was given, when the two are not
/// the same shape.
///
/// Something has to give: the space, the edges, or the proportions.
public enum Aspect: Int32, Sendable {
    /// Fits it all in, keeping the proportions - so there may be space at the
    /// sides. The default.
    case aspectFit = 0

    /// Fills the space, keeping the proportions - so the picture may be cropped.
    case aspectFill = 1

    /// Fills the space, proportions and all - so the picture may be stretched.
    case fill = 2

    /// Drawn at its own size, in the middle.
    case center = 3

    var propValue: PropValue { .enumeration(rawValue) }
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

    var propValue: PropValue { .enumeration(rawValue) }
}

/// How deep a heading is - what `.semanticHeadingLevel` takes.
///
/// A reader who cannot see the page moves through it by its headings, and the
/// level is what tells them whether the next one starts a section or sits
/// inside the one they are in.
public enum SemanticHeadingLevel: Int32, Sendable {
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

    var propValue: PropValue { .enumeration(rawValue) }
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

    var propValue: PropValue { .enumeration(rawValue) }
}

/// The outline a Border draws, and the shape its own background is painted to
/// - which is where a rounded corner comes from on anything but a Button or a
/// ColorBox. What `.strokeShape` takes.
///
///     Border { … }.strokeShape(.roundRectangle(12))
///
/// A shape can carry a number of its own, so this travels as a typed value
/// list whose first element is the KIND and whose rest is what that kind is
/// made of - `.roundRectangle(12)` as `[1, 12]`. The kinds are numbered by
/// this library like everything else here.
public enum StrokeShape: Sendable {
    /// Square corners.
    case rectangle

    /// Rounded corners, by this many device units.
    case roundRectangle(Double)

    /// An oval filling the border's bounds.
    case ellipse

    /// Which shape this is, as the number that crosses - a closed vocabulary,
    /// so the host reads its number rather than its name.
    enum Kind: Int32, Sendable {
        case rectangle = 0
        case roundRectangle = 1
        case ellipse = 2
    }

    /// The kind, then what that kind is made of.
    var propValue: PropValue {
        switch self {
        case .rectangle:
            return .values([.enumeration(Kind.rectangle.rawValue)])
        case .roundRectangle(let radius):
            return .values([.enumeration(Kind.roundRectangle.rawValue), .number(radius)])
        case .ellipse:
            return .values([.enumeration(Kind.ellipse.rawValue)])
        }
    }
}

/// Which parts of a child's bounds an AbsoluteLayout reads as fractions rather
/// than as device units - a flag set, with bits of this library's own.
///
///     .absoluteLayoutBounds(Rect(0.5, 0, 0.5, 1))
///     .absoluteLayoutFlags(.all)
///
/// A fraction is of the LAYOUT's size, so 0.5 is half of it however big it
/// turns out to be - which is the whole reason to reach for an AbsoluteLayout
/// rather than nailing numbers down.
public struct AbsoluteLayoutFlags: OptionSet, Sendable {
    /// The bits, as an OptionSet keeps them - this library's own, see the head
    /// of this file.
    public let rawValue: Int32

    /// From the raw bits. The members below are the ordinary way in.
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// Every number is device units. The default.
    public static let none = AbsoluteLayoutFlags([])

    /// The position across as a fraction.
    public static let xProportional = AbsoluteLayoutFlags(rawValue: 1 << 0)

    /// The position down as a fraction.
    public static let yProportional = AbsoluteLayoutFlags(rawValue: 1 << 1)

    /// Both edges as fractions, the size still in device units.
    public static let positionProportional: AbsoluteLayoutFlags = [.xProportional, .yProportional]

    /// The width as a fraction.
    public static let widthProportional = AbsoluteLayoutFlags(rawValue: 1 << 2)

    /// The height as a fraction.
    public static let heightProportional = AbsoluteLayoutFlags(rawValue: 1 << 3)

    /// Both lengths as fractions, the position still in device units.
    public static let sizeProportional: AbsoluteLayoutFlags = [.widthProportional, .heightProportional]

    /// All four as fractions - the OR of the other four, as a composite here
    /// always is.
    public static let all: AbsoluteLayoutFlags = [.positionProportional, .sizeProportional]

    var propValue: PropValue { .enumeration(rawValue) }
}

/// What a swipe reveals: buttons to tap, or one act carried out by the swipe
/// itself.
public enum SwipeMode: Int32, Sendable {
    /// The items appear and wait to be tapped. The default.
    case reveal = 0

    /// A full swipe runs the first item, with no tap at all.
    case execute = 1

    var propValue: PropValue { .enumeration(rawValue) }
}

/// What the open items do once one of them has run.
public enum SwipeBehaviorOnInvoked: Int32, Sendable {
    /// Closed after a reveal, left open after an execute. The default.
    case auto = 0

    /// Always closed.
    case close = 1

    /// Always left open.
    case remainOpen = 2

    var propValue: PropValue { .enumeration(rawValue) }
}

/// How the end of an open line is drawn.
public enum PenLineCap: Int32, Sendable {
    /// Cut off square at the end point. The default.
    case flat = 0

    /// A half-circle beyond the end point, so the line looks rounded off.
    case round = 1

    /// A square beyond the end point - the same shape as `.flat`, half a stroke
    /// further along.
    case square = 2

    var propValue: PropValue { .enumeration(rawValue) }
}

/// How two segments of a line meet.
public enum PenLineJoin: Int32, Sendable {
    /// A sharp corner, as far out as the two edges reach. The default.
    case miter = 0

    /// The corner cut off flat.
    case bevel = 1

    /// The corner rounded.
    case round = 2

    var propValue: PropValue { .enumeration(rawValue) }
}

/// What a shape does with the room it is given - what `.aspect` takes on a
/// shape. An Image's `.aspect` takes `Aspect` instead.
public enum Stretch: Int32, Sendable {
    /// Drawn at the size its own numbers say, whatever room there is.
    case none = 0

    /// Stretched to fill the room, in both directions independently - a circle
    /// becomes an oval.
    case fill = 1

    /// Scaled to fit the room, keeping its proportions. The default for a
    /// Path.
    case uniform = 2

    /// Scaled to cover the room, keeping its proportions, clipping what does not
    /// fit.
    case uniformToFill = 3

    var propValue: PropValue { .enumeration(rawValue) }
}

/// Which parts of a self-crossing outline count as inside it.
public enum FillRule: Int32, Sendable {
    /// Inside where a ray out of the shape crosses an odd number of edges - so
    /// the middle of a five-pointed star is a hole. The default.
    case evenOdd = 0

    /// Inside where the edges crossed do not cancel out by direction - so the
    /// middle of a star is filled.
    case nonzero = 1

    var propValue: PropValue { .enumeration(rawValue) }
}

/// What one dot of a PositionIndicator is drawn as.
public enum IndicatorShape: Int32, Sendable {
    /// A dot. The default.
    case circle = 0

    /// A square.
    case square = 1

    var propValue: PropValue { .enumeration(rawValue) }
}

/// Where a toolbar item goes in the platform's native action surface.
public enum ToolbarItemOrder: Int32, Sendable {
    /// Wherever the platform normally puts an item.
    case `default` = 0

    /// On the bar itself, where it can be tapped straight away.
    case primary = 1

    /// Behind the native overflow menu.
    case secondary = 2

    var propValue: PropValue { .enumeration(rawValue) }
}

/// What one edge of a layout stays clear of on the screen's UNSAFE strip -
/// the notch, the bars, the soft keyboard. Four combinations, each worth
/// naming; there is no "platform default" case, `.container` being what the
/// one platform that insets does.
///
/// iOS is where it shows; the other platforms have no unsafe strip and
/// ignore it. A layout's default there is `.container` - see
/// `safeAreaEdges`, whose doc says what that costs.
public enum SafeAreaRegions: Int32, Sendable {
    /// Edge to edge: content may run under the notch, the bars and the
    /// keyboard.
    case none = 0

    /// Clear of the soft keyboard, under everything else.
    case softInput = 1

    /// Clear of the bars and the notch, under the keyboard. What an iOS
    /// layout does when nothing is said.
    case container = 2

    /// Clear of everything - bars, notch and keyboard alike.
    case all = 3

    var propValue: PropValue { .enumeration(rawValue) }
}

// MARK: - The choices a channel can carry

// EVERY ONE OF THESE IS A VALUE A PROPERTY CAN BE HANDED as `$x` - the host
// sets it as it stands, and writing the state rebuilds nobody. One line each,
// beside the type, because what makes a choice carriable is its number and
// nothing else: see `StateChoice` in Core/StateValue.swift.

extension AbsoluteLayoutFlags: StateChoice {}
extension Aspect: StateChoice {}
extension FillRule: StateChoice {}
extension LayoutDirection: StateChoice {}
extension FontAttributes: StateChoice {}
extension IndicatorShape: StateChoice {}
extension InputPurpose: StateChoice {}
extension Alignment: StateChoice {}
extension LineBreak: StateChoice {}
extension PenLineCap: StateChoice {}
extension PenLineJoin: StateChoice {}
extension ReturnKey: StateChoice {}
extension SafeAreaRegions: StateChoice {}
extension SemanticHeadingLevel: StateChoice {}
extension ScrollBarVisibility: StateChoice {}
extension ScrollOrientation: StateChoice {}
extension Stretch: StateChoice {}
extension TextAlignment: StateChoice {}
extension TextDecorations: StateChoice {}
extension TextCase: StateChoice {}
