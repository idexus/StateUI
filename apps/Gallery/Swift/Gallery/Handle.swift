// A stable name for a view, built from what it shows.

import StateUI

/// The gallery's rule for `.automationId`: a ROLE and the caption the reader
/// can see, joined with a dot - `handle("switch", "Runs sideways")` is
/// `switch.runs.sideways`.
///
/// It is a rule rather than a name written per call site because a handle has
/// to be PREDICTABLE from outside: a script, a UI test or an agent driving the
/// gallery works one out from what is on screen instead of being told, and a
/// caption that changes takes its handle with it rather than leaving a name
/// that points at nothing.
///
/// A caption is what makes it unique, so two of one role on one page need two
/// captions - which they need anyway, a reader being no better at telling
/// them apart than a driver.
///
/// - Parameters:
///   - role: What kind of thing this is - `card`, `menu`, `switch`, `tab`.
///   - text: What the view shows.
/// - Returns: the role and the caption, lowercased, with everything that is
///   not a letter or a digit collapsed into a single dot.
func handle(_ role: String, _ text: String) -> String {
    var name = role
    var pending = true

    for character in text.lowercased() {
        if character.isLetter || character.isNumber {
            if pending {
                name.append(".")
                pending = false
            }
            name.append(character)
        } else {
            pending = true
        }
    }

    return name
}
