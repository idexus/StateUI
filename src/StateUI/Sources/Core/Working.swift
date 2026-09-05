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
///     @Working private var phase = Phase(Entrance.measuring)  // where the work is
///     @Working private var held = Rect(0, 0, 0, 0)            // the room last seen
///     @Working private var waited = 0.0                       // how long it has held still
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
/// declaration - where a state the host holds takes only what the host can
/// hold, being a value that CROSSES.
///
/// **NAMED FOR WHAT IS IN IT**, where `@State` is named for where the value
/// goes - shown by the tree, or carried by the host where it asks `.never` -
/// and this is what the arithmetic is WORKING with in between. Nothing here is
/// described and no render ever follows a write.
@propertyWrapper
public final class Working<Value>: @unchecked Sendable {
    /// The value, across every render.
    fileprivate(set) var held: WorkingStorage<Value>

    /// State that will hold what it says.
    ///
    /// - Parameter wrappedValue: what it holds before anything writes it.
    public init(wrappedValue: Value) {
        held = WorkingStorage(wrappedValue)
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

    /// What `$phase` gives: the state itself, for a signature that takes one.
    public var projectedValue: Working<Value> { self }
}

extension Working: StateBox {
    /// Takes over the other wrapper's storage, so the two are one value from
    /// here on.
    func adopt(from other: AnyObject) {
        guard let other = other as? Working<Value>, other !== self else { return }

        held = other.held
    }

    /// Tells the value what the author calls it, as a state is told.
    func named(_ path: String) {
        held.origin = BuildScope.readable(path)
    }
}

/// What a `@Working` IS across every render.
///
/// A stamp beside the value, so an engine can be asked "has anything you read
/// moved?" the same way it is asked about a state - which is what makes a
/// handler's write wake the engine that switches on it.
final class WorkingStorage<Value>: @unchecked Sendable, NamedState, AnyWorkingStorage {
    private let guarded = DispatchQueue(label: "StateUI.Working")
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

/// The part of a `@Working` storage an engine's bookkeeping needs, without
/// knowing what the value is.
protocol AnyWorkingStorage: AnyObject {
    /// How many times it has been written.
    var stamp: Int { get }
}
