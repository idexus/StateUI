// MAUI: ProgressBar.

/// ProgressBar's own properties - the half a `Style<ProgressBar>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol ProgressBarProperties: PropertyContainer {}

extension ProgressBarProperties {
    /// How far along, as a FRACTION from 0 to 1 - not a percentage and not a
    /// count of items. MAUI: ProgressBar.Progress, which clamps anything
    /// outside that range.
    public func progress(_ value: Double) -> Modified {
        setValue(.progress, .number(value))
    }

    /// What the FILLED part of the bar is painted.
    /// MAUI: ProgressBar.ProgressColor.
    ///
    /// The track behind it is `.backgroundColor`, from `VisualElement` - the
    /// two are set separately.
    public func progressColor(_ value: Color) -> Modified {
        setValue(.progressColor, value.propValue)
    }
}

/// How far along something is, from 0 to 1. MAUI: ProgressBar.
///
///     @State private var done = 0.0
///
///     ProgressBar(done)
///         .progressColor(.firebrick)
///
/// A FRACTION, not a percentage and not a count: 0.4 is four tenths of the way
/// through, whatever the work is measured in - so a job counting files divides
/// by the total itself. For work with no measurable length, use an
/// `ActivityIndicator`.
///
/// It takes no binding, unlike the inputs: nothing about it is the reader's to
/// change, so the value only ever goes one way. Writing the `@State` it is
/// built from is how it moves.
public struct ProgressBar: View, ProgressBarProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<ProgressBar>` is written against.
    public init() {
        node = Node(type: .progressBar)
    }

    /// A bar filled `progress` of the way, from 0 to 1. MAUI clamps anything
    /// outside that.
    public init(_ progress: Double) {
        node = Node(type: .progressBar, props: [.progress: .number(progress)])
    }

    // MARK: Properties

}
