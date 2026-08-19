// MAUI: ActivityIndicator.

/// ActivityIndicator's own properties - the half a `Style<ActivityIndicator>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol ActivityIndicatorProperties: PropertyContainer {}

extension ActivityIndicatorProperties {
    /// Whether it is spinning. MAUI: ActivityIndicator.IsRunning.
    ///
    /// A still indicator is also an INVISIBLE one on most platforms, so this
    /// is the whole of showing and hiding it - `.isVisible` is not needed
    /// beside it. Usually given in the initializer instead; this is the way to
    /// set it in a style.
    public func isRunning(_ value: Bool) -> Modified {
        setValue(.isRunning, .bool(value))
    }

    /// What colour it spins in. MAUI: ActivityIndicator.Color.
    ///
    /// Not `.backgroundColor`, which paints the square the spinner sits in.
    public func color(_ value: Color) -> Modified {
        setValue(.color, value.propValue)
    }
}

/// The spinner shown while something is happening that has no measurable
/// length.
///
///     @State private var loading = false
///     …
///     ActivityIndicator(loading)
///         .color(.firebrick)
///
/// For work whose progress CAN be measured, use a `ProgressBar` instead: a
/// spinner says "wait", a bar says "how much longer".
///
/// It takes no binding, unlike the inputs: there is nothing here for the reader
/// to change, so the value only ever travels outwards.
public struct ActivityIndicator: View, ActivityIndicatorProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<ActivityIndicator>` is written against.
    public init() {
        node = Node(type: .activityIndicator)
    }

    /// A spinner, spinning or still - and still is also INVISIBLE on most
    /// platforms, which is what makes `ActivityIndicator(loading)` the whole of
    /// showing it while the work runs and hiding it when the work is done.
    public init(_ isRunning: Bool) {
        node = Node(type: .activityIndicator, props: [.isRunning: .bool(isRunning)])
    }

    // MARK: Properties

}
