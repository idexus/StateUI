// MAUI: Picker.

/// Picker's own properties - the half a `Style<Picker>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol PickerProperties: PropertyContainer {}

extension PickerProperties {
    /// The list to choose from, in the order it is offered.
    /// MAUI: Picker.ItemsSource.
    ///
    /// Strings, where MAUI takes any objects and reads their captions through
    /// `ItemDisplayBinding`: a wire carries text, not objects, so an
    /// application choosing among models formats them here and looks the
    /// chosen one up by its index.
    public func itemsSource(_ value: [String]) -> Modified {
        setValue(.itemsSource, .strings(value))
    }

    /// Which item is chosen, counted from zero; -1 for none.
    /// MAUI: Picker.SelectedIndex.
    public func selectedIndex(_ value: Int) -> Modified {
        setValue(.selectedIndex, .number(Double(value)))
    }

    /// What it says while nothing is chosen, and the caption on the sheet the
    /// platform puts up to choose in. MAUI: Picker.Title.
    public func title(_ value: String) -> Modified {
        setValue(.title, .string(value))
    }

    /// The colour of that `title`. MAUI: Picker.TitleColor.
    ///
    /// Not the colour of the chosen item - `.textColor` is that one, from
    /// `TextStyleElement`.
    public func titleColor(_ value: Color) -> Modified {
        setValue(.titleColor, value.propValue)
    }
}

/// One choice out of a list.
///
///     private let sizes = ["Small", "Medium", "Large"]
///     @State private var size = 1
///
///     Picker(sizes)
///         .selectedIndex($size)
///         .title("Size")
///
/// The list is the initializer argument because it is what a Picker is for.
/// Which one is chosen is a binding, so the choice comes back without a
/// handler - as an INDEX into the list, and `-1` while nothing is chosen.
/// Turning that index back into a value is the author's own `sizes[size]`,
/// which is why the list is worth holding rather than writing inline.
///
/// `TextStyleElement` rather than `TextElement`: MAUI's Picker has no Text
/// property - the field shows the chosen item - so there is no `.text()` here
/// to write something it could not show.
public struct Picker: View, TextStyleElement, FontElement, TextAlignmentElement, PickerProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Picker>` is written against.
    public init() {
        node = Node(type: .picker)
    }

    /// A picker offering `items`, with nothing chosen until `.selectedIndex`
    /// says so.
    public init(_ items: [String]) {
        node = Node(type: .picker, props: [.itemsSource: .strings(items)])
    }

    // MARK: Properties

    /// Two-way: shows the chosen item and writes back what the user picks.
    ///
    /// An `.onSelectedIndexChanged` written beside it runs BESIDE this write
    /// rather than replacing it, like every typed event modifier - whichever
    /// order the two are written in. The order decides only who runs FIRST.
    public func selectedIndex(_ binding: Binding<Int>) -> Self {
        selectedIndex(binding.wrappedValue)
            .addHandler(.selectedIndexChanged) {
                if let index = EventBuffer.current.value()?.int {
                    binding.wrappedValue = index
                }
            }
    }

    // MARK: Events

    /// Fires when the choice changes, with the new index.
    ///
    /// Runs in WRITING order with a binding's write: written after
    /// `.selectedIndex($:)` it sees the state already updated, written before
    /// it the state still holds the old index - the payload carries the new
    /// one either way.
    public func onSelectedIndexChanged(_ handler: @escaping ValueEventHandler<Int>) -> Self {
        addHandler(.selectedIndexChanged) {
            // A payload that will not parse leaves the handler alone, the rule
            // every gesture follows. -1 is a real value here - nothing chosen -
            // so it cannot double as "unreadable".
            if let index = EventBuffer.current.value()?.int {
                try await handler(index)
            }
        }
    }
}
