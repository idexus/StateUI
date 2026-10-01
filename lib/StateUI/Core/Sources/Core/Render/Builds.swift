// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Why a view is being described, in the author's own names - what
// `debugInfo()` answers.
// Design: docs/design/core/invalidation.md#why-a-view-is-described

/// A state that can say what the author calls it - worn by the storage, the one
/// object that is the state across renders.
protocol NamedState: AnyObject {
    /// What the author calls it, once a reflection walk has said.
    var origin: String? { get }
}

/// Which view is being described now, and what changed that it had read: one
/// frame per body or bare container's content, pushed around the build.
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

        /// Whether this render describes the whole tree.
        let everything: Bool
    }

    /// The build under way; written and read only by the thread that renders.
    nonisolated(unsafe) static var current: Frame?

    /// Runs a build with its frame in place, answering what the build answered.
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

    /// A state's name as the author reads it: the walk's path without its leading
    /// dot and the wrapper's underscore.
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
    /// Answers the view's name, how many times the closure this is written in has
    /// been described, and which state this description is for -
    /// `"PlacedSample: 47 builds, for aim"`. A view described because an ancestor
    /// was says `with its parent`. Reading it causes no render; outside a body it
    /// says nothing is being described.
    ///
    /// - Returns: what is being described here, how often, and why.
    public func debugInfo() -> String {
        BuildScope.sentence()
    }
}
