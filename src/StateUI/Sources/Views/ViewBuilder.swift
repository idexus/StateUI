// The result builder behind the nested syntax.
//
// It is what turns consecutive statements into a child list:
//
//     VStack {
//         Label("Hello")
//         if signedIn {
//             Button("Sign out").onClicked { signOut() }
//         }
//         ForEach(items) { item in
//             Label(item)
//         }
//     }
//
// Every method works in terms of [Element] rather than Element, which is what
// lets an `if` or a `ForEach` - each of which produces a list, not a single
// view - appear as one statement among others.
//
// WHAT EVERY METHOD ALSO DOES is write down where it was: the statement's
// number, which branch of the `if`. The segments nest into a path -
// "1.else.0" is the first statement of the else branch of the second
// statement - and `Node.key` carries it to the differ.
//
// The reason is that FLATTENING LOSES THE SHAPE. All of these come out of the
// builder as a plain list, and the index is all the differ would otherwise
// have to go on:
//
//     VStack {
//         if signedIn { Label("Welcome") }
//         Entry($search)
//     }
//
// Signed out, the Entry is child 0. Signed in, child 0 is the Label and the
// Entry is child 1 - so by index, signing in matches the new Label against the
// Entry, which is a changed type and therefore a REPLACED control: the search
// box is rebuilt, losing its focus, its caret and its scroll, and rebuilt
// again on signing out. With the path, the Label is "0.some" and the Entry is
// "1" in both states; the Entry is matched to itself and never moves.
//
// The other half is that two branches are two elements, not one:
//
//     if editing { Entry($name) } else { Entry($nickname) }
//
// Both are Entries with the same properties, so by index they are ONE control
// that merely changes its text, and the caret stays put across what the author
// wrote as a switch between two fields. "0.if" and "0.else" are different
// places, so they are different elements.

/// Collects child views written as consecutive statements into an array.
/// Every closure in this library that takes views is one of these.
///
/// `if`, `if/else`, `switch`, `ForEach` and `if #available` all work inside one,
/// and each records where it stood - see the note above this type, and
/// `Node.key`. A plain `for` does NOT compile here: a turn of a loop has no
/// identity but its number, so repetition is `ForEach`, which gives each view
/// its item's identity instead.
///
///     VStack {
///         Label("Files")
///
///         ForEach(files, id: \.path) { file in
///             Label(file.name)
///         }
///     }
@resultBuilder
public enum ViewBuilder {
    /// A single view written as a statement.
    public static func buildExpression(_ expression: Element) -> [Element] {
        [expression]
    }

    /// Several, from something that already produced a list.
    public static func buildExpression(_ expression: [Element]) -> [Element] {
        expression
    }

    /// The statements of the closure, joined in the order they are written.
    ///
    /// Each statement is numbered, and that number is the outermost segment of
    /// everything it produced. A statement keeps its number whatever the
    /// statements around it produce, which is the whole point.
    public static func buildBlock(_ components: [Element]...) -> [Element] {
        components.enumerated().flatMap { at($0.offset, $0.element) }
    }

    /// An `if` without an `else`.
    ///
    /// The branch that ran is marked, so what it produced is never matched
    /// against what the statement AFTER it produced when it did not run.
    public static func buildOptional(_ component: [Element]?) -> [Element] {
        component.map { tag("some", $0) } ?? []
    }

    /// The `if` branch of an if/else.
    public static func buildEither(first component: [Element]) -> [Element] {
        tag("if", component)
    }

    /// The `else` branch.
    ///
    /// Marked differently from the `if` branch on purpose: two branches are two
    /// elements even when they build the same kind of control, so switching
    /// between them replaces the control rather than editing it.
    public static func buildEither(second component: [Element]) -> [Element] {
        tag("else", component)
    }

    /// A loop's views - `ForEach`, each identified by its ITEM.
    ///
    /// There is deliberately no `buildArray`, so a plain `for` does not
    /// compile here: a turn has no identity but its number, which IS the
    /// position - the assumption `ForEach` exists to retire. A collection
    /// that gains a row at the top renumbers every turn below it, and the
    /// views are rebuilt as though each had changed.
    public static func buildExpression(_ expression: ForEach) -> [Element] {
        expression.elements
    }

    /// What an `if #available(…)` block builds - marked with a segment of its
    /// own, the way every other branch is.
    public static func buildLimitedAvailability(_ component: [Element]) -> [Element] {
        tag("available", component)
    }

    /// Puts one segment in front of everything a statement produced.
    ///
    /// A statement that produced SEVERAL views has its own numbering added
    /// under the segment, so a list written as one expression - `buildExpression`
    /// over an array - does not give every element the same path. That inner
    /// number is a position like any other, which does not matter for a
    /// `ForEach` - its views carry their items' ids, and an id wins over the
    /// path - and is why a hand-built `[Element]` whose length changes wants
    /// `ForEach` instead.
    private static func tag(_ segment: String, _ elements: [Element]) -> [Element] {
        guard elements.count > 1 else {
            return elements.map { Keyed(segment: segment, element: $0) }
        }

        return elements.enumerated().map {
            Keyed(segment: "\(segment).\($0.offset)", element: $0.element)
        }
    }

    private static func at(_ index: Int, _ elements: [Element]) -> [Element] {
        tag(String(index), elements)
    }
}

/// One more segment on an element's path, added without touching the element.
///
/// A wrapper rather than a property on the controls, because the builder is
/// handed an `Element` and must not care which one: a Label, a composed view, a
/// memoized subtree and a hand-written `Node` all take the segment the same
/// way. `body` is where it lands, which is also where the parent asks for it -
/// so a wrapped element is built no earlier than an unwrapped one.
struct Keyed: Element {
    /// What to put in front of whatever path the element already has.
    let segment: String

    /// The element as the author wrote it, modifiers and all.
    let element: Element

    /// The element's own node, with the segment on the front of its path.
    var body: Node {
        var node = element.body
        node.key = node.key.map { "\(segment).\($0)" } ?? segment
        return node
    }
}
