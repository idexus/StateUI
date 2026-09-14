#if MAUI
import StateUI

extension NodeType {
    /// The C# Badge, registered under this name.
    static let badge = NodeType("Gallery.Badge")
}

/// The Swift half of the C# Badge: a registered control holding content
/// described here.
///
/// What the closure builds travels as the node's child, and the host
/// reconciles it into the registration's one slot - created, patched and kept
/// by identity. One view, like any single-content control; a layout inside
/// holds more.
struct Badge: View {
    var node = Node(type: .badge)

    /// A badge with nothing under the bubble.
    init() {}

    /// A badge over what the closure describes.
    ///
    /// The closure runs as the badge is built, so a state it reads is read by
    /// the view that writes the badge.
    init(@ViewBuilder content: () -> [Element]) {
        node = Node(type: .badge, children: content().map { $0.body })
    }

    /// What the bubble says; at 0 the bubble hides. C#: `Badge.Count`,
    /// declared in the registration under the library's own `count`.
    func count(_ value: Int) -> Self {
        setValue(.count, .number(Double(value)))
    }
}

/// A registered control with a slot: Swift describes the inside, C# draws the
/// bubble over it.
struct CustomContainerSample: SampleContent, ExampleContent {
    @State private var unread = 3
    @State private var read = false

    static let id = "customContainer"
    static let title = "A C# container"
    static let summary = "A registered C# control holding content described in Swift."

    static let code = """
        extension NodeType {
            static let badge = NodeType("Gallery.Badge")
        }

        struct Badge: View {
            var node = Node(type: .badge)

            init(@ViewBuilder content: () -> [Element]) {
                node = Node(type: .badge, children: content().map { $0.body })
            }

            // The library's own `count`, declared by the C# registration.
            func count(_ value: Int) -> Self {
                setValue(.count, .number(Double(value)))
            }
        }

        @State private var unread = 3
        @State private var read = false

        VStack {
            // The count and the caption are read here, so a press builds this
            // closure, and the inside is patched in place.
            DebugInfoLabel()

            Badge {
                Border {
                    Label(read ? "Inbox, read" : "Inbox")
                        .padding(24, 16)
                }
            }
            .count(unread)

            Button("One more")
                .onClicked {
                    unread += 1
                    read = false
                }

            Button("Read them all")
                .onClicked {
                    unread = 0
                    read = true
                }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Badge {
                Border {
                    Label(read ? "Inbox, read" : "Inbox")
                        .fontSize(17)
                        .padding(24, 16)
                }
            }
            .count(unread)
            .horizontalAlignment(.center)
            .margin(0, 14, 0, 0)

            Button("One more")
                .onClicked {
                    unread += 1
                    read = false
                }

            Button("Read them all")
                .onClicked {
                    unread = 0
                    read = true
                }
        }
        .spacing(8)
    }

    var notes: Element? {
        VStack {
            Label("The inside is Swift's: the caption follows the state and is patched "
                + "in place, never created again. The bubble is the C# control's own "
                + "drawing, told its count through the property its registration "
                + "declares.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The registration's `content` places the reconciled child in the "
                + "control's one slot, and is called only when the slot changes hands. "
                + "Read them all hides the bubble: a badge with nothing to count is just "
                + "its content.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
#endif
