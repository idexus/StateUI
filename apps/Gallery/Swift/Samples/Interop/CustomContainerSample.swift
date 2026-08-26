import StateUI

/// The Badge's vocabulary - a registered CONTAINER, so beside the node type
/// and its one property there is nothing event-shaped: what it holds is the
/// content's business.
extension NodeType {
    /// The C# Badge, registered in MauiProgram under this name.
    static let badge = NodeType("Gallery.Badge")
}

extension Prop {
    /// What the bubble says. C#: Badge.CountProperty - declared in the
    /// registration, so a style or an animation could reach it too.
    static let count = Prop("count")
}

/// The Swift half of the C# Badge - a registered control that HOLDS
/// Swift-described content: what the closure builds travels as the node's
/// child, and the renderer reconciles it into the registration's one slot,
/// the way a Border's content is. One view, like MAUI's own single-content
/// controls; put a layout in it for more.
struct Badge: View {
    var node = Node(type: .badge)

    /// An empty badge - a bubble with nothing under it.
    init() {}

    /// A badge over what the closure describes.
    init(@ViewBuilder content: () -> [Element]) {
        node = Node(type: .badge, children: content().map { $0.body })
    }

    /// What the bubble says; at 0 it hides. C#: Badge.Count.
    func count(_ value: Int) -> Self {
        setValue(.count, .number(Double(value)))
    }
}

/// A registered control with a SLOT: Swift describes the inside, C# draws
/// the bubble over it - and a patch about the inside patches it in place,
/// never re-creating the container.
struct CustomContainerSample: SampleContent {
    @State private var unread = 3
    @State private var flat = false

    static let id = "custom-container"
    static let title = "A C# container"
    static let summary = "A registered control holding Swift-described content."

    static let code = """
        // The wrapper: the child the closure builds travels as the node's
        // child, and the renderer reconciles it into the C# control's one
        // slot - created, patched and kept by identity, a Border's shape.
        extension NodeType { static let badge = NodeType("Gallery.Badge") }
        extension Prop { static let count = Prop("count") }

        struct Badge: View {
            var node = Node(type: .badge)

            init(@ViewBuilder content: () -> [Element]) {
                node = Node(type: .badge, children: content().map { $0.body })
            }

            func count(_ value: Int) -> Self {
                setValue(.count, .number(Double(value)))
            }
        }

        @State private var unread = 3
        @State private var flat = false

        VStack {
            // The inside is ordinary Swift - state-driven, patched in
            // place; the bubble is the C# control's own drawing.
            Badge {
                Border {
                    Label(flat ? "Inbox, read" : "Inbox")
                        .padding(24, 16)
                }
                .strokeThickness(1)
            }
            .count(unread)

            Button("One more")
                .onClicked { unread += 1 }

            Button("Read them all")
                .onClicked {
                    unread = 0
                    flat = true
                }
        }
        """

    /// The other half: a control with a slot the registration's `content`
    /// fills - called only when the slot changes hands, so a patch that
    /// merely updates the held view never lands there.
    static let codeCSharp = """
        public sealed class Badge : ContentView
        {
            public static readonly BindableProperty CountProperty = BindableProperty.Create(
                nameof(Count), typeof(int), typeof(Badge), 0,
                propertyChanged: (bindable, _, _) => ((Badge)bindable).Repaint());

            public int Count
            {
                get => (int)GetValue(CountProperty);
                set => SetValue(CountProperty, value);
            }

            // The one slot. The renderer calls this through the
            // registration's `content` when the slot changes hands.
            public View? Inner
            {
                set
                {
                    if (_inner is not null) { _grid.Children.Remove(_inner); }
                    _inner = value;
                    if (value is not null) { _grid.Children.Insert(0, value); }
                }
            }

            private void Repaint()
            {
                _count.Text = Count.ToString();
                _bubble.IsVisible = Count > 0;
            }

            private readonly Grid _grid;
            private readonly Border _bubble;
            private readonly Label _count;
            private View? _inner;
        }

        // And the registration, in MauiProgram.CreateMauiApp:
        StateUIControls.Add("Gallery.Badge",
            create: _ => new Badge(),
            properties: new Dictionary<string, BindableProperty>
            {
                ["count"] = Badge.CountProperty,
            },
            content: (badge, inner) => badge.Inner = inner);
        """

    var content: Element {
        VStack {
            Badge {
                Border {
                    Label(flat ? "Inbox, read" : "Inbox")
                        .fontSize(17)
                        .padding(24, 16)
                }
                .stroke(Palette.outline)
                .strokeThickness(1)
                .strokeShape(.roundRectangle(12))
            }
            .count(unread)
            .horizontalOptions(.center)
            .margin(0, 14, 0, 0)

            Button("One more")
                .onClicked { unread += 1 }

            Button("Read them all")
                .onClicked {
                    unread = 0
                    flat = true
                }

        }
        .spacing(5)
    }

    var notes: Element? {
        Label("The inside is Swift's - the label re-renders as the state "
            + "moves, patched IN PLACE through the wire like any view - "
            + "while the bubble is the C# control's own drawing, told its "
            + "count through the declared property. Read them all and the "
            + "bubble hides itself: a badge with nothing to count is just "
            + "its content.")
            .fontSize(14)
            .textColor(Palette.subtle)
    }
}
