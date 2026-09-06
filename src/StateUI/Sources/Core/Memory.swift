// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The WORKING MEMORY of an engine's arithmetic.
//
// Not a value the tree describes and not one the host carries: any Swift type
// at all, living only on this side, read and written by the arithmetic that
// owns it. Reading one INSIDE an engine's run is what makes that engine follow
// it, which is why the read goes through `EngineScope` - the bracket that says
// whose run is on. That bracket, and the loop it belongs to, are in
// Core/Engine.swift.

import Dispatch

/// The working memory of an engine's arithmetic - a phase, a counter, a
/// snapshot of where something was. This library's own.
///
///     enum Entrance { case measuring, settling, shown }
///
///     @Memory private var phase = Phase(Entrance.measuring)  // where the work is
///     @Memory private var held = Rect(0, 0, 0, 0)            // the room last seen
///     @Memory private var waited = 0.0                       // how long it has held still
///
/// Any Swift type: no lanes, no bytes, nothing crossing. Kept like `@State` -
/// found by the property's own name, and the same value across every render.
/// AN ENGINE THAT READ ONE FOLLOWS IT, so a handler writing `phase.go(to:)`
/// wakes the engine that switches on it, exactly as a written state does.
///
/// **IT HOLDS ANYTHING AN ENGINE NEEDS, AND NOTHING OF IT LEAVES.** Those two
/// are one fact: nothing has to be representable to anybody, because nobody
/// else ever sees it. So a step of a sequence, a running total, a rectangle
/// held from the last pass and a snapshot to compare against are all the same
/// declaration - where a state the host carries takes only what the host can
/// hold, being a value that CROSSES.
///
/// **NAMED FOR WHAT IS IN IT**, where `@State` is named for who owns it: a
/// state is the tree's - shown by the views that read it, or carried by the
/// host where a modifier or an engine was handed `$x` - and this is what the
/// arithmetic is WORKING with in between. Nothing here is described and no
/// render ever follows a write.
///
/// **AND THIS IS THE ONE DECLARATION AN ENGINE IS WOKEN BY HAVING READ.** A
/// `@State` is followed by NAMING it in `following:`; one merely read inside
/// the run, whatever it asks, is nobody's reason to run. The line between the
/// two is what a reader can see where the engine is declared.
@propertyWrapper
public final class Memory<Value>: @unchecked Sendable {
    /// The value, across every render.
    fileprivate(set) var held: MemoryStorage<Value>

    /// State that will hold what it says.
    ///
    /// - Parameter wrappedValue: what it holds before anything writes it.
    public init(wrappedValue: Value) {
        held = MemoryStorage(wrappedValue)
    }

    /// Where the value stands. Reading it inside an engine says that engine
    /// follows it; reading it anywhere else records nothing.
    public var wrappedValue: Value {
        get {
            EngineScope.read(held)
            return held.value
        }
        set { held.write(newValue) }
    }

    /// What `$phase` gives: a LINK to this memory, for a child to declare as
    /// `@Link var phase: Phase<Step>` and take in its initializer - the same
    /// shape `@State` and `@Binding` have. The link is the memory itself, read
    /// and written through, so an engine in the child that reads it follows
    /// it exactly as the owner's does.
    public var projectedValue: Link<Value> { Link(held) }
}

extension Memory: StateBox {
    /// Takes over the other wrapper's storage, so the two are one value from
    /// here on.
    func adopt(from other: AnyObject) {
        guard let other = other as? Memory<Value>, other !== self else { return }

        held = other.held
    }

    /// Tells the value what the author calls it, as a state is told.
    func named(_ path: String) {
        held.origin = BuildScope.readable(path)
    }
}

/// A link to a `@Memory` somebody else declared - what `$phase` gives, and
/// what a child declares to share an engine's memory with an engine of its
/// own. This library's own.
///
///     struct Steps: ContentView {
///         @Memory private var phase = Phase(Step.waiting)
///
///         var content: Element { Meter(phase: $phase) }
///     }
///
///     struct Meter: ContentView {
///         @Link var phase: Phase<Step>              // the owner's memory, by link
///
///         var content: Element { … }
///     }
///
/// THE MEMORY ITSELF, not a copy: a read through the link inside an engine's
/// run makes that engine follow the memory, a write on either side wakes
/// every engine that read it, and the value is one value across both views.
/// Made only from `$x` on a `@Memory` - there is no `init(wrappedValue:)` on
/// purpose, a link to nothing being nothing - and never adopted by path: the
/// state walk stops at it, as at a `@Binding`, because what it links to is
/// kept by its owner.
///
/// `@unchecked Sendable` for the reason `Binding` is: what it holds is a
/// storage kept safe by its own lock, and an engine's closure captures the
/// view that holds this by value.
@propertyWrapper
public struct Link<Value>: BorrowedState, @unchecked Sendable {
    private let storage: MemoryStorage<Value>

    /// A link to that storage - made by `$x` on a `@Memory` and nowhere else.
    fileprivate init(_ storage: MemoryStorage<Value>) {
        self.storage = storage
    }

    /// Where the value stands. Reading it inside an engine says that engine
    /// follows it; reading it anywhere else records nothing.
    public var wrappedValue: Value {
        get {
            EngineScope.read(storage)
            return storage.value
        }
        nonmutating set { storage.write(newValue) }
    }

    /// The link again, for lending on to a child of the child.
    public var projectedValue: Link<Value> { self }
}

/// What a `@Memory` IS across every render.
///
/// A stamp beside the value, so an engine can be asked "has anything you read
/// moved?" the same way it is asked about a state - which is what makes a
/// handler's write wake the engine that switches on it.
final class MemoryStorage<Value>: @unchecked Sendable, NamedState, AnyMemoryStorage {
    private let guarded = DispatchQueue(label: "StateUI.Memory")
    private var held: Value

    /// How many times it has been written.
    nonisolated(unsafe) private(set) var stamp: Int = 0

    /// What the author calls it - the reflection walk's.
    nonisolated(unsafe) var origin: String?

    init(_ value: Value) {
        held = value
    }

    /// The value, read whole.
    var value: Value { guarded.sync { held } }

    /// The value, written whole, and counted.
    func write(_ newValue: Value) {
        guarded.sync {
            held = newValue
            stamp += 1
        }
    }
}

/// The part of a `@Memory` storage an engine's bookkeeping needs, without
/// knowing what the value is.
protocol AnyMemoryStorage: AnyObject {
    /// How many times it has been written.
    var stamp: Int { get }
}
