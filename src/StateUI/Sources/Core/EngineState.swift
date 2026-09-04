// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Memory an engine keeps between its own runs.
//
// Not a value the tree describes and not one the host carries: any Swift type
// at all, living only on this side, read and written by the arithmetic that
// owns it. Reading one INSIDE an engine's run is what makes that engine follow
// it, which is why the read goes through `EngineScope` - the bracket that says
// whose run is on. That bracket, and the loop it belongs to, are in
// Core/Engine.swift.

import Dispatch

/// Memory an engine keeps between cycles and nothing else sees - a phase, a
/// counter, a snapshot of where something was. This library's own.
///
///     @EngineState private var phase = Steps(Step.waiting)
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
/// declaration - where `@Animated` takes only what can be walked and `@Bus`
/// only what the host can hold, both of them being values that CROSS.
///
/// It is named for its OWNER, as each of the four declarations is: `@State` is
/// the tree's, `@Animated` and `@Bus` are the host's, this is one engine's own.
/// Nothing here is described and no render ever follows a write - what makes it
/// unlike a `@State` is not how it rebuilds but whose it is.
@propertyWrapper
public final class EngineState<Value>: @unchecked Sendable {
    /// The value, across every render.
    fileprivate(set) var held: EngineStateStorage<Value>

    /// State that will hold what it says.
    ///
    /// - Parameter wrappedValue: what it holds before anything writes it.
    public init(wrappedValue: Value) {
        held = EngineStateStorage(wrappedValue)
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
    public var projectedValue: EngineState<Value> { self }
}

extension EngineState: StateBox {
    /// Takes over the other wrapper's storage, so the two are one value from
    /// here on.
    func adopt(from other: AnyObject) {
        guard let other = other as? EngineState<Value>, other !== self else { return }

        held = other.held
    }

    /// Tells the value what the author calls it, as a state is told.
    func named(_ path: String) {
        held.origin = BuildScope.readable(path)
    }
}

/// What an `@EngineState` IS across every render.
///
/// A stamp beside the value, so an engine can be asked "has anything you read
/// moved?" the same way it is asked about a state - which is what makes a
/// handler's write wake the engine that switches on it.
final class EngineStateStorage<Value>: @unchecked Sendable, NamedState, AnyEngineStateStorage {
    private let guarded = DispatchQueue(label: "StateUI.EngineState")
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

/// The part of an `@EngineState` storage an engine's bookkeeping needs, without
/// knowing what the value is.
protocol AnyEngineStateStorage: AnyObject {
    /// How many times it has been written.
    var stamp: Int { get }
}
