// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Which state was read where - the half of invalidation the differ cannot see.
//
// The fallback answer to "what changed" is: something did, so run the author's
// closure in full and diff the result. That is always correct - but for a large
// tree it builds every page so that one label can change. The clean walk in
// Core/Diff.swift needs two facts recorded as they happen, and this file is
// where the first is kept:
//
//   reads     while a body or a container's content is being built, every
//             piece of state it reads is recorded against THAT element - the
//             closure that read it, and no closure around it - so the next
//             render can ask "did anything this build depended on move?"
//             without building anything, and build again exactly the closure
//             that read.
//   changes   every write names the state it wrote. That half lives on the
//             Renderer (`stateChanged`), beside the dirty flag it extends.
//
// The identity in both is the STORAGE, not the box: a `@State` box is rebuilt
// with its view on every render and adopts its predecessor's storage
// (State.adopt), so the storage is the one object that means "this piece of
// state" across renders. A `@State` declared in a class has a storage of its
// own the same way, and a Ticker is its own.
//
// Both directions err toward REBUILDING, never toward skipping: a recycled
// ObjectIdentifier, a read recorded from a pool thread mid-render, a `@State`
// read in a branch the body did not take this time - each can only add a
// dependency or a change that was not strictly needed, and the cost of any of
// them is a subtree built and diffed for nothing. A dependency MISSED would be
// a frozen interface, which is why writes always land (behind the renderer's
// lock) and why anything that cannot name what changed falls back to the full
// build.

import Dispatch

/// The read scopes open right now, innermost last.
///
/// The differ opens one around each build it runs, and `Renderer.renderWire`
/// opens one around the root build itself - the reads that happen outside
/// every composed view, which is what decides whether the application needs
/// building at all.
///
/// Builds never nest across elements - a body constructs its children's
/// PLACEHOLDERS, never their bodies - so the stack is depth one in practice.
/// It is a stack anyway, because `Node.built` in a test expands everything
/// eagerly and nothing here should be surprised by that.
enum ReadScope {
    /// Guards the stack. Reads may arrive from a pool thread - an author's task
    /// reading a `@State` while the UI thread renders - and an insert racing a
    /// pop would corrupt the array.
    private static let guarded = DispatchQueue(label: "StateUI.ReadScope")

    private nonisolated(unsafe) static var stack: [Set<ObjectIdentifier>] = []

    /// How many scopes are open, kept beside the stack for the fast path below.
    private nonisolated(unsafe) static var depth = 0

    /// Records a read into the innermost open scope, if any.
    ///
    /// Called on EVERY read of every `@State` in the process, almost all of
    /// them from handlers with no scope open - so the empty check is an
    /// unsynchronized read of `depth`, not a trip through the lock. That is
    /// safe by argument rather than by the compiler: the thread that opens and
    /// closes scopes is the thread that renders, so a read there always sees
    /// the truth; a pool thread may see a stale value, and either direction is
    /// harmless - noting a read that lands in some element's set over-records
    /// a dependency, and skipping one records nothing a pool-thread read was
    /// entitled to anyway.
    ///
    /// - Returns: whether a scope was open to record it - which is what tells
    ///   a read at BUILD from every other read of the same state.
    @discardableResult
    static func note(_ id: ObjectIdentifier) -> Bool {
        guard depth > 0 else { return false }

        return guarded.sync {
            guard !stack.isEmpty else { return false }

            stack[stack.count - 1].insert(id)
            return true
        }
    }

    /// Runs a build with a scope of its own open, and returns what it read.
    static func collect<T>(_ build: () -> T) -> (value: T, reads: Set<ObjectIdentifier>) {
        guarded.sync {
            stack.append([])
            depth += 1
        }

        let value = build()

        let reads = guarded.sync { () -> Set<ObjectIdentifier> in
            depth -= 1
            return stack.removeLast()
        }

        return (value, reads)
    }

    /// The same, accumulating into a set the caller keeps - the differ unwraps
    /// a chain of placeholders one build at a time, and they all belong to the
    /// one element.
    static func collect<T>(
        into reads: inout Set<ObjectIdentifier>,
        _ build: () -> T
    ) -> T {
        let (value, found) = collect(build)
        reads.formUnion(found)
        return value
    }
}
