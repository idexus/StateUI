import StateUI

/// The build reading for the closure this call sits in, drawn in its top right
/// corner.
///
/// A CALL AND NOT A VIEW, which is the whole of why it works. `debugInfo()`
/// answers about the description that is RUNNING when it is called, so a
/// reading taken inside a container's braces counts THAT container - the very
/// closure a state read there rebuilds. A view of its own would push a
/// description of its own in front and answer about itself: `1 build, with its
/// parent`, for ever, whatever the sample is doing.
///
/// So it is written exactly where the question is, and the sample's `code`
/// shows it in the same place:
///
///     VStack {
///         DebugInfoLabel()                    // the outer closure: reads nothing
///
///         VStack {
///             DebugInfoLabel()                // this one: built whenever `volume` moves
///             Label("Volume \(volume)")
///         }
///     }
///
/// - Returns: the count and the reason - `41 builds, for volume` - as a label
///   the caller may go on modifying, which is what a grid cell needs.
func DebugInfoLabel() -> Label {
    // ANY element can be asked. The sentence is about the description that is
    // running, never about the view it is asked through, which is what lets
    // this be a function at all rather than a view.
    Label(BuildCount.of(Label("").debugInfo()))
        .fontSize(12)
        .textColor(Palette.accent)
        .horizontalOptions(.end)
        .horizontalTextAlignment(.end)
        .inputTransparent(true)
}

/// The build count on its own, without the view's name.
enum BuildCount {
    /// `debugInfo()` less the name in front of it.
    ///
    /// The name is the one part of that sentence the reader already has: it is
    /// the title of the page they are looking at, or of the tab. What is left
    /// is the whole of what a reading says - `1 build, first time`,
    /// `41 builds, for volume`.
    ///
    /// - Parameter info: what `debugInfo()` answered.
    /// - Returns: the count and the reason, or the whole sentence where there
    ///   is no name in front to drop.
    static func of(_ info: String) -> String {
        guard let colon = info.firstIndex(of: ":") else { return info }

        var rest = info[info.index(after: colon)...]

        while rest.first == " " {
            rest = rest.dropFirst()
        }

        return rest.isEmpty ? info : String(rest)
    }
}
