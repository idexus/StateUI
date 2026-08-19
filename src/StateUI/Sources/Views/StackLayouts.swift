// MAUI: VerticalStackLayout and HorizontalStackLayout.
//
// The one abbreviation in the library: VStack and HStack are aliases for the
// real types, because VerticalStackLayout appears in nearly every tree and is a
// lot of characters to read past. Both spellings work, and everything else -
// Spacing, Padding, Margin - keeps the MAUI name.

/// Stacks its children top to bottom, each as tall as it asks to be.
/// MAUI: VerticalStackLayout.
///
///     VStack {
///         Label("One")
///         Label("Two")
///     }
///     .spacing(12)
///     .padding(24)
///
/// Children go in the trailing closure; everything else is a modifier, so the
/// layout of the code follows the layout on screen.
///
/// Three sizes are easy to confuse: `.spacing` is the gap BETWEEN children,
/// `.padding` is the room inside the stack's own edges, and `.margin` is the
/// room outside them.
///
/// A stack grows as tall as its children need and does not scroll, so a column
/// longer than the screen wants a `ScrollView` around it. A column that must
/// DIVIDE a fixed height among its children is a `Grid` instead.
public struct VerticalStackLayout: StackBase {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<VerticalStackLayout>` is written against.
    public init() {
        node = Node(type: .verticalStackLayout)
    }

    /// A column of whatever the closure describes, in the order written.
    public init(@ViewBuilder content: () -> [Element]) {
        node = Node(type: .verticalStackLayout, children: content().map { $0.body })
    }
}

/// Stacks its children left to right, each as wide as it asks to be.
/// MAUI: HorizontalStackLayout.
///
///     HStack {
///         Image("nav_home.png")
///         Label("Home")
///     }
///     .spacing(8)
///
/// A stack takes as much room as its children need and does not wrap - a row of
/// text longer than the screen is cut off rather than folded. A `Grid` is the
/// way to divide a width up, and a `FlexLayout` the way to let a row fold onto
/// the next line.
public struct HorizontalStackLayout: StackBase {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<HorizontalStackLayout>` is written against.
    public init() {
        node = Node(type: .horizontalStackLayout)
    }

    /// A row of whatever the closure describes, in the order written.
    public init(@ViewBuilder content: () -> [Element]) {
        node = Node(type: .horizontalStackLayout, children: content().map { $0.body })
    }
}

/// `VerticalStackLayout` under a shorter name - the same type, so the two
/// spellings mix freely and a `Style<VerticalStackLayout>` reaches both.
public typealias VStack = VerticalStackLayout

/// `HorizontalStackLayout` under a shorter name - the same type, so the two
/// spellings mix freely and a `Style<HorizontalStackLayout>` reaches both.
public typealias HStack = HorizontalStackLayout
