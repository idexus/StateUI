// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The typed boundary for a host linked into the same Swift process.
//
// MAUI cannot consume Swift values and therefore keeps using Wire. A native
// Swift host does not need to turn this tree into bytes only to read it back,
// so it receives the same sparse patch directly. The SPI keeps this machinery
// out of an application's API while allowing host packages maintained beside
// StateUI to depend on it deliberately.

/// A property value delivered directly to a native Swift host.
@_spi(Host) public typealias HostValue = PropValue

/// Which way a state crosses at a native-host attachment.
@_spi(Host) public typealias HostStateMode = StateMode

/// Which native-host channel carries an attached state.
@_spi(Host) public typealias HostStateKind = StateKind

/// A state image delivered directly to, or reported by, a native Swift host.
@_spi(Host) public typealias HostStateValue = StateCarried

/// One state channel attached to a native property.
@_spi(Host) public struct HostStateBinding: Equatable, Sendable {
    /// The channel number quoted back to StateUI by a host.
    public let state: Int32

    /// Which direction the value crosses.
    public let mode: HostStateMode

    /// Which native-host channel carries the value.
    public let kind: HostStateKind
}

/// One state value published by a completed host cycle.
@_spi(Host) public struct HostStateChange: Equatable, Sendable {
    /// The state channel whose value changed.
    public let state: Int32

    /// The lanes that changed, or every bit for text.
    public let changed: UInt64

    /// The complete value after the cycle.
    public let value: HostStateValue
}

/// The result of advancing one native-host clock.
@_spi(Host) public struct HostCycle: Equatable, Sendable {
    /// Complete values for the state channels changed by this cycle.
    public let changes: [HostStateChange]

    /// Whether an engine or pending state needs another cycle.
    public let continues: Bool
}

/// A property transition accompanying its target value.
@_spi(Host) public struct HostTransition: Equatable, Sendable {
    /// How the property moves to its target.
    public let motion: Motion
}

/// A changed movement law for children placed by a layout.
@_spi(Host) public struct HostLayoutMotion: Equatable, Sendable {
    /// How the child placement moves.
    public let motion: Motion

    /// Which placement coordinates move under that law.
    public let lanes: MotionLanes
}

/// How a sparse patch changes an element's children.
@_spi(Host) public enum HostChildrenUpdate: Sendable {
    /// The children and their order did not change.
    case unchanged

    /// Only these existing or new descendants changed.
    case changed([HostPatch])

    /// The complete child arrangement, in this order.
    case arranged([HostPatch])
}

/// How a sparse patch changes host-driven state attachments.
@_spi(Host) public enum HostDrivenUpdate: Sendable {
    /// Replaces the complete attachment map; an empty map removes every attachment.
    case replace([Prop: HostStateBinding])
}

/// How a sparse patch changes native event handlers.
@_spi(Host) public enum HostEventUpdate: Sendable {
    /// Replaces the complete event map; an empty map removes every handler.
    case replace([Event: Int32])
}

/// What changed about one element, and about the elements under it.
///
/// Every update field is empty or optional when it did not change, so an
/// element that is only carrying the path down to a changed child is two
/// fields wide. The one rule every host reads it by: **absence means
/// unchanged**. A property removed from an element is named explicitly in
/// `clearedProperties`; replacement is reserved for changes a control cannot
/// accept in place.
@_spi(Host) public struct HostPatch: Sendable {
    /// Stable identity used to find or retain the native control.
    public let id: ElementId

    /// The kind of native control or structural element this patch describes.
    public let type: NodeType

    /// The native control cannot be updated into what the node now says, so the
    /// host discards it and builds it again from this complete patch.
    ///
    /// Set when the element type changed, and for a property that has gone away
    /// which no host-neutral operation can put back - `Prop.notCleared`, and
    /// nothing else. Every other lost property is named in `clearedProperties`
    /// instead, which costs one property rather than the element and its subtree.
    public var replace = false

    /// Whether this render brings the complete element. Renderer-only merge
    /// bookkeeping; it is not part of the host contract and never crosses a
    /// typed or Wire boundary.
    var fresh = false

    /// Only the properties that changed. All of them when `replace` is set or
    /// the element is new.
    public var properties: [Prop: HostValue] = [:]

    /// The properties this element described last render and does not
    /// describe now, in name order.
    ///
    /// The host clears each one, so what the modifier stood for goes back to
    /// that native control's default. Without this a property that has gone
    /// away has nothing arriving to overwrite it, and the only honest answer
    /// left is to build the control again.
    public var clearedProperties: [Prop] = []

    /// The properties among `properties` the host is to move to rather than
    /// assign, and how. Empty on almost every patch there ever is.
    ///
    /// A moved property is ordinary in every other respect: its target is in
    /// `properties`, the differ compares it normally, and a host that ignores
    /// this field simply snaps to that target.
    public var transitions: [Prop: HostTransition] = [:]

    /// The properties driven to a state, sent whole whenever the set changed.
    ///
    /// Nil means unchanged; `.replace([:])` means forget every attachment.
    public var driven: HostDrivenUpdate?

    /// The complete event map, sent only when the set of handled events changed.
    /// Nil means unchanged; `.replace([:])` removes every handler.
    public var events: HostEventUpdate?

    /// How this element's children travel when it puts them somewhere new,
    /// sent when it changed and only by an element that places children.
    public var motion: HostLayoutMotion?

    /// Whether this element's children are recycled, or nil when unchanged.
    public var recycles: Bool?

    /// The recyclable subtree shape, or nil when unchanged. Zero means the
    /// subtree cannot be recycled.
    public var shape: UInt64?

    /// The sparse or complete change to this element's children.
    public var children: HostChildrenUpdate = .unchanged
}

extension HostChildrenUpdate: RandomAccessCollection {
    /// The integer position of a patch in this update's payload.
    public typealias Index = Int

    /// The first index in the update's patch payload.
    public var startIndex: Int { patches.startIndex }

    /// One past the last index in the update's patch payload.
    public var endIndex: Int { patches.endIndex }

    /// A patch in the sparse or arranged payload.
    public subscript(position: Int) -> HostPatch { patches[position] }
}

/// One renderer result delivered directly to a native Swift host.
@_spi(Host) public struct HostRender: Sendable {
    /// The generation the host should retain after applying this result.
    public let generation: Int32

    /// Whether the root patch completely describes the current tree.
    public let complete: Bool

    /// The root element's sparse patch.
    public let root: HostPatch
}

/// One operation requested from a native host.
@_spi(Host) public struct HostCommand: Sendable {
    /// The operation's stable StateUI token.
    public let act: Act

    /// Typed arguments in the operation's declared order.
    public let arguments: [HostValue]

    /// The negative continuation id, or nil when no answer is expected.
    public let completion: Int?
}

/// Operations a native Swift host performs on the StateUI runtime.
@_spi(Host) public enum StateUIHost {
    /// Whether state changed since the last render.
    public static var needsRender: Bool { Renderer.shared.needsRender }

    /// Updates the appearance used to resolve themed values before rendering.
    public static func setTheme(_ theme: AppTheme) {
        StandardEnvironment.app.requestedTheme = theme
    }

    /// Builds and returns a typed patch against the generation the host holds.
    public static func render(baseline: Int32) -> HostRender {
        Renderer.shared.renderHost(baseline: baseline)
    }

    /// Reads the complete image for an outward state attachment.
    ///
    /// Text and plain values arrive in their declared shape. A moving
    /// property carries its complete journey so a host can retain one motion
    /// channel for every state number.
    public static func value(for binding: HostStateBinding) -> HostStateValue? {
        Renderer.shared.hostValue(for: binding)
    }

    /// Reports a complete text, plain value, or feed through an inward state
    /// attachment.
    ///
    /// A moving property reports through its host motion channel instead; its
    /// image contains the value, destination, velocity, law and completion,
    /// rather than only the value a reader moved.
    @discardableResult
    public static func report(
        _ value: HostStateValue,
        through binding: HostStateBinding
    ) -> Bool {
        Renderer.shared.hostReported(value, through: binding)
    }

    /// Advances one StateUI clock and returns the state values it published.
    public static func cycle(
        _ sync: Sync,
        now: Double,
        reducesMotion: Bool
    ) -> HostCycle {
        Renderer.shared.hostCycle(sync: sync, now: now, reducesMotion: reducesMotion)
    }

    /// Whether any state or engine is waiting for a host cycle.
    public static var cyclesPending: Bool { Renderer.shared.cycleAwake() != 0 }

    /// Reports a native event and runs its handler on StateUI's UI executor.
    @discardableResult
    public static func dispatch(_ handler: Int32, payload: [HostValue] = []) -> Bool {
        EventBuffer.current = payload
        return Renderer.shared.dispatch(Int(handler))
    }

    /// Runs jobs waiting on StateUI's UI executor on the calling thread.
    @discardableResult
    public static func runJobs() -> Int { stateUIRunJobs() }

    /// Parks the calling doorbell thread until asynchronous work arrives.
    public static func waitForWork() -> Int {
        MainThreadExecutor.shared.waitForWork()
            + Renderer.shared.commandsPending
            + (Renderer.shared.needsRender ? 1 : 0)
    }

    /// Takes operations queued since the previous host pump.
    public static func takeCommands() -> [HostCommand] {
        Renderer.shared.takeCommands().map(HostCommand.init)
    }

    /// Fails continuations from the last taken command batch.
    public static func failTakenCommands(_ reason: String) {
        Renderer.shared.failTakenCommands(reason)
    }
}

extension HostStateBinding {
    init(_ entry: StateEntry) {
        state = entry.number
        mode = entry.mode
        kind = entry.kind
    }
}

extension HostCommand {
    init(_ command: Command) {
        act = command.act
        arguments = command.arguments
        completion = command.completion
    }
}
