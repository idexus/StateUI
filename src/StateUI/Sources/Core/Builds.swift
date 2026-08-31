// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// WHY A VIEW IS BEING DESCRIBED, said in the author's own names.
//
// A render rebuilds exactly the views whose recorded reads intersect the state
// that changed (Core/Invalidation.swift, `Differ.revisit`), and everything
// under them. Which view that turns out to be is the one question an author
// asks while a screen is being made smooth, and until now the only way to
// answer it was to reason about where a value is read.
//
// So the differ keeps three things it already had within reach, and this file
// hands them to `debugInfo()`:
//
//   the view      the composed view whose body is running right now.
//   how often     how many times THIS element has been described, kept on the
//                 element so it survives every render that leaves it alone.
//   why           the state this element read LAST time that has been written
//                 since - the very intersection the walk decided by.
//
// Nothing here is computed until it is asked for. The frame carries the two
// sets by reference and the intersection is taken inside `debugInfo()`, so a
// render nobody is watching pays for a build counter and two assignments.
//
// A STATE IS NAMED BY THE PATH THE REFLECTION WALK REACHED IT BY - the same
// path that pairs it with its predecessor across a render (Core/Stateful.swift)
// - which is the author's own property name, and costs a string that walk had
// already built. A state nothing owns that way - a `@StateClass` model, a
// ticker - is named by its type, which is what an author calls it too.

/// A piece of state that can say what it is called.
///
/// Worn by the STORAGE rather than the box: a `@State` box is rebuilt with its
/// view on every render and adopts its predecessor's storage, so the storage is
/// the one object that means "this piece of state" across renders - and the one
/// a write names.
protocol NamedState: AnyObject {
    /// What the author calls it, once a reflection walk has said.
    var origin: String? { get }
}

/// Which view is being described right now, and what changed that it had read.
///
/// One frame per composed view whose body is running, pushed by the differ
/// around the build and popped however it returns. Depth is one in practice - a
/// body constructs its children's placeholders, never their bodies - and a
/// stack anyway, because a composed view made of another unwraps in one pass.
enum BuildScope {
    /// One view's build, as it stands.
    struct Frame {
        /// The view's Swift type, module-qualified.
        let view: String

        /// How many times this element has been described, this one included.
        let builds: Int

        /// What the element's builds read LAST render - empty the first time.
        let read: Set<ObjectIdentifier>

        /// The state written since the tree on screen was built.
        let changed: Set<ObjectIdentifier>

        /// What each of those is called, by storage identity.
        let names: [ObjectIdentifier: String]

        /// Whether this render is describing the whole tree rather than
        /// walking to what changed.
        let everything: Bool
    }

    /// The build under way, or nothing outside every body.
    ///
    /// Written only by the thread that renders, which is the one that reads it.
    nonisolated(unsafe) static var current: Frame?

    /// Runs a build with its frame in place.
    ///
    /// - Parameters:
    ///   - frame: what is being described, and why.
    ///   - build: the build to run.
    /// - Returns: whatever the build answered.
    static func within<T>(_ frame: Frame, _ build: () -> T) -> T {
        let outer = current
        current = frame
        defer { current = outer }

        return build()
    }

    /// The sentence `debugInfo()` answers with.
    static func sentence() -> String {
        guard let frame = current else {
            return "nothing is being described here"
        }

        let times = frame.builds == 1 ? "1 build" : "\(frame.builds) builds"

        return "\(short(frame.view)): \(times), \(reason(frame))"
    }

    /// Why this build is happening.
    private static func reason(_ frame: Frame) -> String {
        if frame.builds == 1 {
            return "first time"
        }

        let causes = frame.read.intersection(frame.changed)

        if !causes.isEmpty {
            return "for " + causes
                .map { frame.names[$0] ?? "state" }
                .sorted()
                .joined(separator: ", ")
        }

        return frame.everything ? "the whole tree" : "with its parent"
    }

    /// A type without its module, which is what an author calls it.
    private static func short(_ type: String) -> String {
        String(type.split(separator: ".").last ?? "a view")
    }

    /// A state's name for a reader: the reflection walk's path without the
    /// leading dot and the underscore a property wrapper's storage wears.
    static func readable(_ path: String) -> String {
        var name = Substring(path)

        while name.first == "." || name.first == "_" {
            name = name.dropFirst()
        }

        return name.isEmpty ? path : String(name)
    }
}

extension Element {
    /// Why this view is being described, and how often. This library's own.
    ///
    ///     Label(debugInfo())
    ///
    /// Answers the view's own name, how many times it has been described, and
    /// WHICH piece of state this description is for -
    /// `"PlacedSample: 47 builds, for offset"` - naming the state by the
    /// property the author declared it as. A view described because an
    /// ancestor was says `with its parent`, which is what tells a view that
    /// reads a value from one that merely sits under a view that does: the
    /// rebuild starts at the outermost view naming a state, and everything
    /// below it goes along.
    ///
    /// It is a reading rather than a report, so put it where a reading goes -
    /// a `Label` on the screen being worked on, or a value handed to whatever
    /// prints. Reading it does not itself cause a render.
    ///
    /// Called INSIDE a body, where a description is under way; anywhere else
    /// there is nothing being described and it says so.
    ///
    /// - Returns: what is being described here, how often, and why.
    public func debugInfo() -> String {
        BuildScope.sentence()
    }
}
