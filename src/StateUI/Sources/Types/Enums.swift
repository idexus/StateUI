// The enumerations a MAUI property takes, with MAUI's names.
//
// Each case is the MAUI member camelCased, so `LayoutOptions.Center` is
// `.center` and `LineBreakMode.TailTruncation` is `.tailTruncation`, and every
// case's `///` says WHICH MAUI member it stands for. What a case does not carry
// is MAUI's number.
//
// THE NUMBERS ON THIS WIRE ARE OURS. A closed vocabulary rides the wire as a
// number rather than a spelling, and that number is this library's own. MAUI's
// own values are MAUI's internal business: a release is free to renumber an
// enum or insert a member in the middle of one and break nothing on its own
// side - and a wire carrying those values would then be reinterpreted SILENTLY,
// every property on it reading as a different member, with nothing failing
// anywhere. Ours cannot move, so a MAUI upgrade cannot reach them.
//
// The far side does the translating, and it translates by NAME: the C# half
// holds an internal mirror enum per type carrying these same numbers, and maps
// each of its members onto the MAUI member named in the `///` here. That
// pairing - case to MAUI member - is the contract; the number is only how it
// crosses. `WireEnumTests.cs` READS these declarations and compares them
// against the mirrors, so the two lists cannot drift apart without a red test.
//
// Declaration order from 0, and it has no exceptions. The numbers are written
// out rather than left to the compiler because they are a wire contract: a case
// inserted in the middle would silently shift every case after it, and seeing
// the numbers is what makes that hard to do by accident. Appending a case is
// free; inserting or reordering one is not.
//
// MAUI's flag enumerations (FontAttributes, TextDecorations,
// AbsoluteLayoutFlags) are OptionSets here, so both `.bold` and
// `[.bold, .italic]` work, just as the [Flags] enum does in C#. Their bits are
// ours by the same rule - `1 << 0` upwards in declaration order - and a
// composite is written as the OR of its parts, so a bit set travels as nothing
// more than its bits.

/// Where a view sits in the space its layout gives it. MAUI: LayoutOptions.
///
/// MAUI's LayoutOptions is a STRUCT rather than an enum, and what a case here
/// stands for is one member of its `Alignment` -
/// `Microsoft.Maui.Controls.LayoutAlignment`, which is what the far side sets.
public enum LayoutOptions: Int32, Sendable {
    /// At the near edge - the left, or the top - taking only the room it needs.
    /// MAUI: LayoutAlignment.Start.
    case start = 0

    /// In the middle, taking only the room it needs.
    /// MAUI: LayoutAlignment.Center.
    case center = 1

    /// At the far edge, taking only the room it needs.
    /// MAUI: LayoutAlignment.End.
    case end = 2

    /// Taking all of it. MAUI's default, and LayoutAlignment.Fill.
    case fill = 3

    var propValue: PropValue { .enumeration(rawValue) }
}

/// Whether text is drawn bold, italic, or both. MAUI: FontAttributes, a
/// [Flags] enum - with bits numbered here rather than there.
///
///     Label("Total").fontAttributes(.bold)
///     Label("Total").fontAttributes([.bold, .italic])
///
/// Only the weight and the slant: the family is `.fontFamily` and the size
/// `.fontSize`, each its own modifier as it is its own MAUI property.
public struct FontAttributes: OptionSet, Sendable {
    /// The bits, as an OptionSet keeps them - this library's own, see the head
    /// of this file.
    public let rawValue: Int32

    /// From the raw bits. `.bold`, `.italic` and `[.bold, .italic]` are the
    /// ordinary way in.
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// Neither bold nor italic. MAUI: FontAttributes.None.
    public static let none = FontAttributes([])

    /// MAUI: FontAttributes.Bold.
    public static let bold = FontAttributes(rawValue: 1 << 0)

    /// MAUI: FontAttributes.Italic.
    public static let italic = FontAttributes(rawValue: 1 << 1)

    var propValue: PropValue { .enumeration(rawValue) }
}

/// Where text sits inside the space its own control was given.
/// MAUI: TextAlignment, numbered here rather than there.
///
/// What `.horizontalTextAlignment` and `.verticalTextAlignment` take. NOT
/// `.horizontalOptions`, which moves the whole control inside its layout: a
/// label centred with this one still occupies the same box.
public enum TextAlignment: Int32, Sendable {
    /// Against the near edge - the left in a left-to-right language.
    /// MAUI: TextAlignment.Start.
    case start = 0

    /// Centred. MAUI: TextAlignment.Center.
    case center = 1

    /// Against the far edge. MAUI: TextAlignment.End.
    case end = 2

    var propValue: PropValue { .enumeration(rawValue) }
}

/// What text does when it will not fit on one line - wrap, or be cut short
/// with an ellipsis. MAUI: LineBreakMode, numbered here rather than there.
///
/// The truncating cases need the control to be BOUNDED to show anything: a
/// label free to grow never runs out of room, so nothing is ever cut.
public enum LineBreakMode: Int32, Sendable {
    /// One line, whatever it costs. MAUI: LineBreakMode.NoWrap.
    case noWrap = 0

    /// Wraps at spaces. MAUI's default for a Label, and LineBreakMode.WordWrap.
    case wordWrap = 1

    /// Wraps mid-word where a word does not fit.
    /// MAUI: LineBreakMode.CharacterWrap.
    case characterWrap = 2

    /// One line, cut at the START, with an ellipsis there.
    /// MAUI: LineBreakMode.HeadTruncation.
    case headTruncation = 3

    /// One line, cut at the END, with an ellipsis there.
    /// MAUI: LineBreakMode.TailTruncation.
    case tailTruncation = 4

    /// One line, cut in the MIDDLE - which keeps both ends readable, as a file
    /// path wants. MAUI: LineBreakMode.MiddleTruncation.
    case middleTruncation = 5

    var propValue: PropValue { .enumeration(rawValue) }
}

/// The lines drawn through or under text. MAUI: TextDecorations, a [Flags]
/// enum - with bits numbered here rather than there.
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

    /// Plain text. MAUI: TextDecorations.None.
    public static let none = TextDecorations([])

    /// A line under the text. MAUI: TextDecorations.Underline.
    public static let underline = TextDecorations(rawValue: 1 << 0)

    /// A line through it. MAUI: TextDecorations.Strikethrough.
    public static let strikethrough = TextDecorations(rawValue: 1 << 1)

    var propValue: PropValue { .enumeration(rawValue) }
}

/// Whether the text is drawn as written, or in one case throughout.
/// MAUI: TextTransform, numbered here rather than there.
///
/// The letters the reader SEES change; the value behind them does not - an
/// `Entry` set to `.uppercase` still reports what was typed, so this is a look
/// rather than an edit.
public enum TextTransform: Int32, Sendable {
    /// As written. MAUI: TextTransform.None.
    case none = 0

    /// As the platform sees fit, which everywhere is as written.
    /// MAUI: TextTransform.Default.
    case `default` = 1

    /// all in lower case. MAUI: TextTransform.Lowercase.
    case lowercase = 2

    /// ALL IN UPPER CASE - a heading, a button's caption.
    /// MAUI: TextTransform.Uppercase.
    case uppercase = 3

    var propValue: PropValue { .enumeration(rawValue) }
}

/// The on-screen keyboard for a text input. MAUI: Keyboard, whose members are
/// static properties on a CLASS rather than enum cases - so there is no MAUI
/// enum here even in principle, and the far side reaches the eight static
/// properties these name.
public enum Keyboard: Int32, Sendable {
    /// Whatever the platform offers, with its own correction and capitalization.
    /// MAUI: Keyboard.Default.
    case `default` = 0

    /// The default one with no correction, capitalization or suggestions.
    /// MAUI: Keyboard.Plain.
    case plain = 1

    /// Set up for conversation - emoji, and no autocorrection getting in the way.
    /// MAUI: Keyboard.Chat.
    case chat = 2

    /// With @ and . to hand. MAUI: Keyboard.Email.
    case email = 3

    /// Digits only. MAUI: Keyboard.Numeric.
    case numeric = 4

    /// A phone dialler's keypad. MAUI: Keyboard.Telephone.
    case telephone = 5

    /// General text, with the platform's spellcheck and capitalization.
    /// MAUI: Keyboard.Text.
    case text = 6

    /// With / and .com to hand. MAUI: Keyboard.Url.
    case url = 7

    var propValue: PropValue { .enumeration(rawValue) }
}

/// The label on the keyboard's return key. MAUI: ReturnType, numbered here
/// rather than there.
public enum ReturnType: Int32, Sendable {
    /// Whatever the platform calls it. MAUI: ReturnType.Default.
    case `default` = 0

    /// "Done". MAUI: ReturnType.Done.
    case done = 1

    /// "Go". MAUI: ReturnType.Go.
    case go = 2

    /// "Next", for a field with another after it. MAUI: ReturnType.Next.
    case next = 3

    /// "Search". MAUI: ReturnType.Search.
    case search = 4

    /// "Send". MAUI: ReturnType.Send.
    case send = 5

    var propValue: PropValue { .enumeration(rawValue) }
}

/// When an `Entry` shows the button that empties it.
/// MAUI: ClearButtonVisibility, numbered here rather than there.
public enum ClearButtonVisibility: Int32, Sendable {
    /// No clear button at all. MAUI: ClearButtonVisibility.Never.
    case never = 0

    /// While there is text and the field has the focus. MAUI's default, and
    /// ClearButtonVisibility.WhileEditing.
    case whileEditing = 1

    var propValue: PropValue { .enumeration(rawValue) }
}

/// Which ways a `ScrollView` scrolls.
/// MAUI: ScrollOrientation, numbered here rather than there.
public enum ScrollOrientation: Int32, Sendable {
    /// Up and down. MAUI's default, and ScrollOrientation.Vertical.
    case vertical = 0

    /// Sideways. MAUI: ScrollOrientation.Horizontal.
    case horizontal = 1

    /// Both at once. MAUI: ScrollOrientation.Both.
    case both = 2

    /// Neither - which is how a ScrollView is stopped from scrolling without
    /// being replaced. MAUI: ScrollOrientation.Neither.
    case neither = 3

    var propValue: PropValue { .enumeration(rawValue) }
}

/// How a `FlyoutPage` shows its two halves.
/// MAUI: FlyoutLayoutBehavior, numbered here rather than there.
///
/// It says how the two halves SHARE THE SCREEN, never whether there is a
/// flyout at all: a FlyoutPage is made of its two pages and always has both.
public enum FlyoutLayoutBehavior: Int32, Sendable {
    /// What the platform does by itself - a drawer on a phone, side by side on
    /// a wide screen. MAUI's own default, and FlyoutLayoutBehavior.Default.
    case `default` = 0

    /// Over the detail page, whatever the screen is - a drawer everywhere.
    /// MAUI: FlyoutLayoutBehavior.Popover.
    case popover = 1

    /// Beside the detail page, whatever the screen is. The flyout cannot be
    /// closed in this one: it is part of the layout, so `isPresented` stops
    /// meaning anything a reader can change.
    /// MAUI: FlyoutLayoutBehavior.Split.
    case split = 2

    /// Beside it when the screen is wider than it is tall, over it otherwise.
    /// MAUI: FlyoutLayoutBehavior.SplitOnLandscape.
    case splitOnLandscape = 3

    /// Beside it when the screen is taller than it is wide, over it otherwise.
    /// MAUI: FlyoutLayoutBehavior.SplitOnPortrait.
    case splitOnPortrait = 4

    var propValue: PropValue { .enumeration(rawValue) }
}

/// How a page presented over the window covers the screen.
/// MAUI: UIModalPresentationStyle, numbered here rather than there, set by the
/// `Page.ModalPresentationStyle` platform-specific.
///
/// **iOS and Mac Catalyst only, and it is UIKit's own list** - the name is
/// MAUI's, which took UIKit's. Android and Windows have no such choice and
/// present every modal page over the whole window; a page written for one of
/// the sheet styles therefore has to look right full screen too.
///
/// Written on the page that is PRESENTED, not on the one presenting it:
///
///     struct SettingsPage: ContentPage {
///         var modalPresentationStyle: UIModalPresentationStyle? { .pageSheet }
///     }
public enum UIModalPresentationStyle: Int32, Sendable {
    /// The whole screen, with nothing of the page underneath left showing.
    /// MAUI's default, the only thing the other platforms do, and
    /// UIModalPresentationStyle.FullScreen.
    case fullScreen = 0

    /// A panel centred on the screen and smaller than it, the page underneath
    /// dimmed around it. On a phone iOS draws this as `pageSheet`; the
    /// difference shows on an iPad and on a Mac.
    /// MAUI: UIModalPresentationStyle.FormSheet.
    case formSheet = 1

    /// Whatever the system would choose, which UIKit maps to `pageSheet` for
    /// almost every page. The modern iOS default, and not MAUI's.
    /// MAUI: UIModalPresentationStyle.Automatic.
    case automatic = 2

    /// A card over the content, the top of the page underneath still showing,
    /// which the reader can DRAG DOWN to dismiss - so a page presented like
    /// this can go away without anything of yours being touched. The bound
    /// stack is truncated when it does.
    /// MAUI: UIModalPresentationStyle.PageSheet.
    case pageSheet = 3

    /// Over the whole screen, with the page underneath LEFT IN PLACE rather
    /// than taken away - the one to present a page with a TRANSPARENT
    /// background over, since there is then something to see through to. A
    /// sheet drawn and animated by hand is written this way.
    /// MAUI: UIModalPresentationStyle.OverFullScreen.
    case overFullScreen = 4

    /// A bubble pointing at whatever presented it. iPad and Mac; on a phone
    /// UIKit falls back to a sheet.
    /// MAUI: UIModalPresentationStyle.Popover.
    case popover = 5

    var propValue: PropValue { .enumeration(rawValue) }
}

/// A transform applied to a Path's geometry - what `.renderTransform` takes.
/// MAUI: Transform and the classes under it, numbered here rather than there.
///
///     Path("M 0 0 L 40 0 L 40 40 Z")
///         .renderTransform(.skew(x: 20, y: 0))
///
/// THE DIFFERENCE from `.rotation` and `.scale`, which every view has: those
/// turn and resize the VIEW after the layout has placed it, while this one
/// changes the GEOMETRY the path is drawn from - so the stroke follows the
/// transform, and a skew is possible at all.
public indirect enum Transform: Sendable {
    /// Turns the geometry, in degrees clockwise, about a point given in the
    /// path's own units. MAUI: RotateTransform.
    case rotate(Double, centerX: Double = 0, centerY: Double = 0)

    /// Resizes it about a point, 1 being its own size. MAUI: ScaleTransform.
    case scale(x: Double, y: Double, centerX: Double = 0, centerY: Double = 0)

    /// Leans it over, in degrees, about a point - which nothing on the view
    /// tier can do. MAUI: SkewTransform.
    case skew(x: Double, y: Double, centerX: Double = 0, centerY: Double = 0)

    /// Moves it, in the path's own units. MAUI: TranslateTransform.
    case translate(x: Double, y: Double)

    /// All of it at once, as the six numbers of an affine matrix.
    /// MAUI: MatrixTransform, whose Matrix these are.
    case matrix(
        m11: Double, m12: Double, m21: Double, m22: Double,
        offsetX: Double, offsetY: Double)

    /// Several, applied in the order written. MAUI: TransformGroup.
    ///
    /// MAUI's `CompositeTransform` says the same thing with fixed slots, so
    /// there is no case for it: a group of the four is the one spelling.
    case group([Transform])

    /// Which transform this is, as the number that crosses - a closed
    /// vocabulary, so both sides of this repository spell it rather than
    /// sending the name. Mirrored by `SwiftTransformKind`.
    enum Kind: Int32, Sendable {
        case rotate = 0
        case scale = 1
        case skew = 2
        case translate = 3
        case matrix = 4
        case group = 5
    }

    /// The kind, then what that kind is made of - and for a group, the parts
    /// as values of their own, which is what lets one hold another.
    var propValue: PropValue {
        switch self {
        case .rotate(let angle, let centerX, let centerY):
            return .values([
                .enumeration(Kind.rotate.rawValue),
                .number(angle), .number(centerX), .number(centerY),
            ])

        case .scale(let x, let y, let centerX, let centerY):
            return .values([
                .enumeration(Kind.scale.rawValue),
                .number(x), .number(y), .number(centerX), .number(centerY),
            ])

        case .skew(let x, let y, let centerX, let centerY):
            return .values([
                .enumeration(Kind.skew.rawValue),
                .number(x), .number(y), .number(centerX), .number(centerY),
            ])

        case .translate(let x, let y):
            return .values([
                .enumeration(Kind.translate.rawValue), .number(x), .number(y),
            ])

        case .matrix(let m11, let m12, let m21, let m22, let offsetX, let offsetY):
            return .values([
                .enumeration(Kind.matrix.rawValue),
                .number(m11), .number(m12), .number(m21), .number(m22),
                .number(offsetX), .number(offsetY),
            ])

        case .group(let transforms):
            return .values([.enumeration(Kind.group.rawValue)] + transforms.map(\.propValue))
        }
    }
}

/// Whether a Label's text is read as plain text or as HTML - what
/// `.textType` takes. MAUI: TextType, numbered here rather than there.
///
/// `.html` hands the string to the platform's own HTML renderer, so a `<b>` is
/// bold and an `<a>` is a link. THE TRAP is that the font and colour modifiers
/// then compete with whatever the markup says, and which wins is the
/// platform's business - a Label showing HTML is best left unstyled.
public enum TextType: Int32, Sendable {
    /// The string as written, which is MAUI's default and what a Label
    /// normally shows. MAUI: TextType.Text.
    case text = 0

    /// The string as markup. MAUI: TextType.Html.
    case html = 1

    var propValue: PropValue { .enumeration(rawValue) }
}

/// What a map pin stands for - what `.type` takes, and what decides the icon
/// the platform draws. MAUI: PinType, numbered here rather than there.
public enum PinType: Int32, Sendable {
    /// Somewhere on the map, with no more said. MAUI's default, and
    /// PinType.Generic.
    case generic = 0

    /// A place - a shop, a station, a landmark. MAUI: PinType.Place.
    case place = 1

    /// One the reader saved. MAUI: PinType.SavedPin.
    case savedPin = 2

    /// One a search turned up. MAUI: PinType.SearchResult.
    case searchResult = 3

    var propValue: PropValue { .enumeration(rawValue) }
}

/// How a picture fills the space an `Image` was given, when the two are not
/// the same shape. MAUI: Aspect, numbered here rather than there.
///
/// Something has to give: the space, the edges, or the proportions.
public enum Aspect: Int32, Sendable {
    /// Fits it all in, keeping the proportions - so there may be space at the
    /// sides. MAUI's default, and Aspect.AspectFit.
    case aspectFit = 0

    /// Fills the space, keeping the proportions - so the picture may be cropped.
    /// MAUI: Aspect.AspectFill.
    case aspectFill = 1

    /// Fills the space, proportions and all - so the picture may be stretched.
    /// MAUI: Aspect.Fill.
    case fill = 2

    /// Drawn at its own size, in the middle. MAUI: Aspect.Center.
    case center = 3

    var propValue: PropValue { .enumeration(rawValue) }
}

/// Which way a view lays its content out, and which edge it starts from -
/// what `.flowDirection` takes.
/// MAUI: FlowDirection, numbered here rather than there.
///
/// The point of it is a language written right to left: a view told
/// `.rightToLeft` mirrors its layout, so a stack fills from the right and a
/// label's natural alignment moves with it.
public enum FlowDirection: Int32, Sendable {
    /// Whatever the view above says, which is how a view inherits the
    /// application's. MAUI's default, and FlowDirection.MatchParent.
    case matchParent = 0

    /// Left to right, whatever the view above says.
    /// MAUI: FlowDirection.LeftToRight.
    case leftToRight = 1

    /// Right to left, whatever the view above says.
    /// MAUI: FlowDirection.RightToLeft.
    case rightToLeft = 2

    var propValue: PropValue { .enumeration(rawValue) }
}

/// When the scroll bars are drawn - what `.verticalScrollBarVisibility` and
/// `.horizontalScrollBarVisibility` take.
/// MAUI: ScrollBarVisibility, numbered here rather than there.
public enum ScrollBarVisibility: Int32, Sendable {
    /// As the platform sees fit. MAUI: ScrollBarVisibility.Default.
    case `default` = 0

    /// Always shown. MAUI: ScrollBarVisibility.Always.
    case always = 1

    /// Never shown, though it still scrolls. MAUI: ScrollBarVisibility.Never.
    case never = 2

    var propValue: PropValue { .enumeration(rawValue) }
}

/// Whether an `Editor` grows taller as more is typed into it.
/// MAUI: EditorAutoSizeOption, numbered here rather than there.
public enum EditorAutoSizeOption: Int32, Sendable {
    /// A fixed height, which is MAUI's default.
    /// MAUI: EditorAutoSizeOption.Disabled.
    case disabled = 0

    /// Grows as the text does. MAUI: EditorAutoSizeOption.TextChanges.
    case textChanges = 1

    var propValue: PropValue { .enumeration(rawValue) }
}

/// The outline a Border draws, and the shape its own background is painted to
/// - which is where a rounded corner comes from on anything but a Button or a
/// BoxView. MAUI: Border.StrokeShape, an IShape.
///
///     Border { … }.strokeShape(.roundRectangle(12))
///
/// An IShape is an OBJECT rather than a member of anything, so there is no MAUI
/// member for a case to stand for: this travels as a typed value list whose
/// first element is the KIND and whose rest is what that kind is made of -
/// `.roundRectangle(12)` as `[1, 12]`. The kinds are numbered by this library
/// like everything else here, and mirrored by `SwiftStrokeShapeKind`.
public enum StrokeShape: Sendable {
    /// Square corners.
    case rectangle

    /// Rounded corners, by this many device units.
    case roundRectangle(Double)

    /// An oval filling the border's bounds.
    case ellipse

    /// Which shape this is, as the number that crosses - a closed vocabulary,
    /// so both sides of this repository spell it rather than sending the name.
    /// Mirrored by `SwiftStrokeShapeKind`.
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

/// How an items view lays its items out, and which way it scrolls.
/// MAUI: ItemsLayout - a LinearItemsLayout or a GridItemsLayout, an OBJECT
/// rather than a member of anything.
///
///     CarouselView { … }.itemsLayout(.horizontalList)
///
/// So there is no MAUI member for a case to stand for: this travels as a typed
/// value list, the KIND first and the span after it where the kind is a grid -
/// `.verticalGrid(2)` as `[2, 2]`. The kinds are numbered by this library like
/// everything else here, and mirrored by `SwiftItemsLayoutKind`.
public enum ItemsLayout: Sendable {
    /// One column, scrolling down. MAUI's default.
    case verticalList

    /// One row, scrolling sideways.
    case horizontalList

    /// This many columns, scrolling down.
    case verticalGrid(Int)

    /// This many rows, scrolling sideways.
    case horizontalGrid(Int)

    /// Which layout this is, as the number that crosses - a closed vocabulary,
    /// so both sides of this repository spell it rather than sending the name.
    /// Mirrored by `SwiftItemsLayoutKind`.
    enum Kind: Int32, Sendable {
        case verticalList = 0
        case horizontalList = 1
        case verticalGrid = 2
        case horizontalGrid = 3
    }

    /// The kind, then the span where there is one.
    var propValue: PropValue {
        switch self {
        case .verticalList:
            return .values([.enumeration(Kind.verticalList.rawValue)])
        case .horizontalList:
            return .values([.enumeration(Kind.horizontalList.rawValue)])
        case .verticalGrid(let span):
            return .values([.enumeration(Kind.verticalGrid.rawValue), .number(Double(span))])
        case .horizontalGrid(let span):
            return .values([.enumeration(Kind.horizontalGrid.rawValue), .number(Double(span))])
        }
    }
}

/// Which parts of a child's bounds an AbsoluteLayout reads as fractions rather
/// than as device units. MAUI: AbsoluteLayoutFlags, a [Flags] enum - with bits
/// numbered here rather than there.
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

    /// Every number is device units. MAUI's default, and
    /// AbsoluteLayoutFlags.None.
    public static let none = AbsoluteLayoutFlags([])

    /// MAUI: AbsoluteLayoutFlags.XProportional.
    public static let xProportional = AbsoluteLayoutFlags(rawValue: 1 << 0)

    /// MAUI: AbsoluteLayoutFlags.YProportional.
    public static let yProportional = AbsoluteLayoutFlags(rawValue: 1 << 1)

    /// Both edges as fractions, the size still in device units.
    /// MAUI: AbsoluteLayoutFlags.PositionProportional.
    public static let positionProportional: AbsoluteLayoutFlags = [.xProportional, .yProportional]

    /// MAUI: AbsoluteLayoutFlags.WidthProportional.
    public static let widthProportional = AbsoluteLayoutFlags(rawValue: 1 << 2)

    /// MAUI: AbsoluteLayoutFlags.HeightProportional.
    public static let heightProportional = AbsoluteLayoutFlags(rawValue: 1 << 3)

    /// Both lengths as fractions, the position still in device units.
    /// MAUI: AbsoluteLayoutFlags.SizeProportional.
    public static let sizeProportional: AbsoluteLayoutFlags = [.widthProportional, .heightProportional]

    /// All four as fractions - the OR of the other four, as a composite here
    /// always is. MAUI: AbsoluteLayoutFlags.All.
    public static let all: AbsoluteLayoutFlags = [.positionProportional, .sizeProportional]

    var propValue: PropValue { .enumeration(rawValue) }
}

/// Which way a FlexLayout lays its children out. MAUI: FlexDirection, numbered
/// here rather than there.
public enum FlexDirection: Int32, Sendable {
    /// Left to right. MAUI's default, and FlexDirection.Row.
    case row = 0

    /// Right to left. MAUI: FlexDirection.RowReverse.
    case rowReverse = 1

    /// Top to bottom. MAUI: FlexDirection.Column.
    case column = 2

    /// Bottom to top. MAUI: FlexDirection.ColumnReverse.
    case columnReverse = 3

    var propValue: PropValue { .enumeration(rawValue) }
}

/// Whether a FlexLayout starts a new line when it runs out of room.
/// MAUI: FlexWrap, numbered here rather than there.
public enum FlexWrap: Int32, Sendable {
    /// One line, however tight it gets. MAUI's default, and FlexWrap.NoWrap.
    case noWrap = 0

    /// A new line when the children no longer fit. MAUI: FlexWrap.Wrap.
    case wrap = 1

    /// The same, with the lines stacked the other way round.
    /// MAUI: FlexWrap.Reverse.
    case reverse = 2

    var propValue: PropValue { .enumeration(rawValue) }
}

/// How the spare room along a FlexLayout's own direction is shared out.
/// MAUI: FlexJustify, numbered here rather than there.
public enum FlexJustify: Int32, Sendable {
    /// The children together in the middle. MAUI: FlexJustify.Center.
    case center = 0

    /// Together at the start. MAUI's default, and FlexJustify.Start.
    case start = 1

    /// Together at the end. MAUI: FlexJustify.End.
    case end = 2

    /// The gaps between children, nothing at the ends.
    /// MAUI: FlexJustify.SpaceBetween.
    case spaceBetween = 3

    /// A gap around each child, so the ends get half of one.
    /// MAUI: FlexJustify.SpaceAround.
    case spaceAround = 4

    /// Every gap the same, the ends included.
    /// MAUI: FlexJustify.SpaceEvenly.
    case spaceEvenly = 5

    var propValue: PropValue { .enumeration(rawValue) }
}

/// Where the children sit ACROSS a FlexLayout's direction - the other axis to
/// `justifyContent`. MAUI: FlexAlignItems, numbered here rather than there.
public enum FlexAlignItems: Int32, Sendable {
    /// Each child fills the cross axis. MAUI's default, and
    /// FlexAlignItems.Stretch.
    case stretch = 0

    /// Centred on it. MAUI: FlexAlignItems.Center.
    case center = 1

    /// At its near edge. MAUI: FlexAlignItems.Start.
    case start = 2

    /// At its far edge. MAUI: FlexAlignItems.End.
    case end = 3

    var propValue: PropValue { .enumeration(rawValue) }
}

/// How several LINES are spread across the cross axis, once the layout wraps.
/// Does nothing while everything is on one line. MAUI: FlexAlignContent,
/// numbered here rather than there.
public enum FlexAlignContent: Int32, Sendable {
    /// The lines share the room between them. MAUI's default, and
    /// FlexAlignContent.Stretch.
    case stretch = 0

    /// Together in the middle. MAUI: FlexAlignContent.Center.
    case center = 1

    /// Together at the near edge. MAUI: FlexAlignContent.Start.
    case start = 2

    /// Together at the far edge. MAUI: FlexAlignContent.End.
    case end = 3

    /// The gaps between lines, nothing at the ends.
    /// MAUI: FlexAlignContent.SpaceBetween.
    case spaceBetween = 4

    /// A gap around each line. MAUI: FlexAlignContent.SpaceAround.
    case spaceAround = 5

    /// Every gap the same. MAUI: FlexAlignContent.SpaceEvenly.
    case spaceEvenly = 6

    var propValue: PropValue { .enumeration(rawValue) }
}

/// One child's answer to `alignItems`, for a child that wants a different one.
/// MAUI: FlexAlignSelf, numbered here rather than there.
public enum FlexAlignSelf: Int32, Sendable {
    /// Whatever the layout said. MAUI's default, and FlexAlignSelf.Auto.
    case auto = 0

    /// Fills the cross axis. MAUI: FlexAlignSelf.Stretch.
    case stretch = 1

    /// Centred on it. MAUI: FlexAlignSelf.Center.
    case center = 2

    /// At its near edge. MAUI: FlexAlignSelf.Start.
    case start = 3

    /// At its far edge. MAUI: FlexAlignSelf.End.
    case end = 4

    var propValue: PropValue { .enumeration(rawValue) }
}

/// Whether a FlexLayout arranges its children or lets them place themselves.
/// MAUI: FlexPosition, numbered here rather than there.
public enum FlexPosition: Int32, Sendable {
    /// The layout places them. MAUI's default, and FlexPosition.Relative.
    case relative = 0

    /// Each child keeps the bounds it was given, and the layout only measures.
    /// MAUI: FlexPosition.Absolute.
    case absolute = 1

    var propValue: PropValue { .enumeration(rawValue) }
}

/// How much room a FlexLayout's child asks for before the spare room is shared.
/// MAUI: FlexBasis, a STRUCT of a length and whether that length is a fraction,
/// so there is no MAUI member for a case to stand for - and MAUI's own
/// converter for it is internal, which is why this side takes the struct apart
/// instead.
///
/// It travels as a typed value list: the KIND - auto, relative, absolute,
/// numbered by this library like everything else here and mirrored by
/// `SwiftFlexBasisKind` - then the length where there is one. A relative
/// length is the SHARE, from 0 to 1, which is what MAUI's own constructor
/// takes: XAML's `50%` is 0.5 here.
public enum FlexBasis: Sendable {
    /// Whatever the child measures at. MAUI: FlexBasis.Auto.
    case auto

    /// A share of the line, from 0 to 1: `.percent(0.5)` is XAML's `50%`.
    case percent(Double)

    /// Exactly this many device units.
    case length(Double)

    /// Which sort of basis this is, as the number that crosses - a closed
    /// vocabulary, so both sides of this repository spell it rather than
    /// sending the name. Mirrored by `SwiftFlexBasisKind`.
    enum Kind: Int32, Sendable {
        case auto = 0
        case relative = 1
        case absolute = 2
    }

    /// The kind, then the length where there is one.
    var propValue: PropValue {
        switch self {
        case .auto:
            return .values([.enumeration(Kind.auto.rawValue)])
        case .percent(let share):
            return .values([.enumeration(Kind.relative.rawValue), .number(share)])
        case .length(let value):
            return .values([.enumeration(Kind.absolute.rawValue), .number(value)])
        }
    }
}

/// What a swipe reveals: buttons to tap, or one act carried out by the swipe
/// itself. MAUI: SwipeMode, numbered here rather than there.
public enum SwipeMode: Int32, Sendable {
    /// The items appear and wait to be tapped. MAUI's default, and
    /// SwipeMode.Reveal.
    case reveal = 0

    /// A full swipe runs the first item, with no tap at all.
    /// MAUI: SwipeMode.Execute.
    case execute = 1

    var propValue: PropValue { .enumeration(rawValue) }
}

/// What the open items do once one of them has run.
/// MAUI: SwipeBehaviorOnInvoked, numbered here rather than there.
public enum SwipeBehaviorOnInvoked: Int32, Sendable {
    /// Closed after a reveal, left open after an execute. MAUI's default, and
    /// SwipeBehaviorOnInvoked.Auto.
    case auto = 0

    /// Always closed. MAUI: SwipeBehaviorOnInvoked.Close.
    case close = 1

    /// Always left open. MAUI: SwipeBehaviorOnInvoked.RemainOpen.
    case remainOpen = 2

    var propValue: PropValue { .enumeration(rawValue) }
}

/// How the end of an open line is drawn. MAUI: PenLineCap, numbered here rather
/// than there.
public enum PenLineCap: Int32, Sendable {
    /// Cut off square at the end point. MAUI's default, and PenLineCap.Flat.
    case flat = 0

    /// A half-circle beyond the end point, so the line looks rounded off.
    /// MAUI: PenLineCap.Round.
    case round = 1

    /// A square beyond the end point - the same shape as `.flat`, half a stroke
    /// further along. MAUI: PenLineCap.Square.
    case square = 2

    var propValue: PropValue { .enumeration(rawValue) }
}

/// How two segments of a line meet. MAUI: PenLineJoin, numbered here rather
/// than there.
public enum PenLineJoin: Int32, Sendable {
    /// A sharp corner, as far out as the two edges reach. MAUI's default, and
    /// PenLineJoin.Miter.
    case miter = 0

    /// The corner cut off flat. MAUI: PenLineJoin.Bevel.
    case bevel = 1

    /// The corner rounded. MAUI: PenLineJoin.Round.
    case round = 2

    var propValue: PropValue { .enumeration(rawValue) }
}

/// What a shape does with the room it is given. MAUI: Stretch, which is what
/// `Shape.Aspect` is - not `Aspect`, which is an Image's - and numbered here
/// rather than there.
public enum Stretch: Int32, Sendable {
    /// Drawn at the size its own numbers say, whatever room there is.
    /// MAUI: Stretch.None.
    case none = 0

    /// Stretched to fill the room, in both directions independently - a circle
    /// becomes an oval. MAUI: Stretch.Fill.
    case fill = 1

    /// Scaled to fit the room, keeping its proportions. MAUI's default for a
    /// Path, and Stretch.Uniform.
    case uniform = 2

    /// Scaled to cover the room, keeping its proportions, clipping what does not
    /// fit. MAUI: Stretch.UniformToFill.
    case uniformToFill = 3

    var propValue: PropValue { .enumeration(rawValue) }
}

/// Which parts of a self-crossing outline count as inside it. MAUI: FillRule,
/// numbered here rather than there.
public enum FillRule: Int32, Sendable {
    /// Inside where a ray out of the shape crosses an odd number of edges - so
    /// the middle of a five-pointed star is a hole. MAUI's default, and
    /// FillRule.EvenOdd.
    case evenOdd = 0

    /// Inside where the edges crossed do not cancel out by direction - so the
    /// middle of a star is filled. MAUI: FillRule.Nonzero.
    case nonzero = 1

    var propValue: PropValue { .enumeration(rawValue) }
}

/// What one dot of an IndicatorView is drawn as. MAUI: IndicatorShape, numbered
/// here rather than there.
public enum IndicatorShape: Int32, Sendable {
    /// A dot. MAUI's default, and IndicatorShape.Circle.
    case circle = 0

    /// A square. MAUI: IndicatorShape.Square.
    case square = 1

    var propValue: PropValue { .enumeration(rawValue) }
}

/// Where a toolbar item goes. MAUI: ToolbarItemOrder, numbered here rather than
/// there.
public enum ToolbarItemOrder: Int32, Sendable {
    /// Wherever the platform puts one. MAUI's default, and
    /// ToolbarItemOrder.Default.
    case `default` = 0

    /// On the bar itself, where it can be tapped straight away.
    /// MAUI: ToolbarItemOrder.Primary.
    case primary = 1

    /// Behind the overflow menu. MAUI: ToolbarItemOrder.Secondary.
    case secondary = 2

    var propValue: PropValue { .enumeration(rawValue) }
}

/// What one edge of a layout stays clear of on the screen's UNSAFE strip -
/// the notch, the bars, the soft keyboard. MAUI: SafeAreaRegions, numbered here
/// rather than there - MAUI's is a [Flags] enum, this is the four combinations
/// worth naming, and MAUI's `Default` - "apply platform defaults" - has no case
/// here, `.container` being what the one platform that insets does.
///
/// iOS is where it shows; the other platforms have no unsafe strip and
/// ignore it. A layout's default there is `.container`, and MAUI applies the
/// inset at ARRANGE time only - see `safeAreaEdges`, whose doc says what that
/// costs.
public enum SafeAreaRegions: Int32, Sendable {
    /// Edge to edge: content may run under the notch, the bars and the
    /// keyboard. MAUI: SafeAreaRegions.None.
    case none = 0

    /// Clear of the soft keyboard, under everything else.
    /// MAUI: SafeAreaRegions.SoftInput.
    case softInput = 1

    /// Clear of the bars and the notch, under the keyboard. What an iOS
    /// layout does when nothing is said. MAUI: SafeAreaRegions.Container.
    case container = 2

    /// Clear of everything - bars, notch and keyboard alike.
    /// MAUI: SafeAreaRegions.All.
    case all = 3

    var propValue: PropValue { .enumeration(rawValue) }
}
