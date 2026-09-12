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

/// One state channel attached to a native property.
@_spi(Host) public struct HostStateBinding: Equatable, Sendable {
    /// The channel number quoted back to StateUI by a host.
    public let state: Int32

    /// Which direction the value crosses.
    public let mode: HostStateMode

    /// Which native-host channel carries the value.
    public let kind: HostStateKind
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

/// The sparse change for one element delivered to a native Swift host.
@_spi(Host) public struct HostPatch: Sendable {
    /// Stable identity used to find or retain the native control.
    public let id: ElementId

    /// The kind of native control or structural element this patch describes.
    public let type: NodeType

    /// Whether the existing native control must be replaced.
    public var replace = false

    /// Properties that are new or changed.
    public var properties: [Prop: HostValue] = [:]

    /// Properties that returned to their native defaults.
    public var clearedProperties: [Prop] = []

    /// Per-property movements accompanying values in `properties`.
    public var transitions: [Prop: HostTransition] = [:]

    /// The complete state-channel replacement, or nil when it did not change.
    public var driven: HostDrivenUpdate?

    /// The complete event-map replacement, or nil when it did not change.
    public var events: HostEventUpdate?

    /// A changed movement law for children placed by this element.
    public var motion: HostLayoutMotion?

    /// Whether children may be recycled, or nil when it did not change.
    public var recycles: Bool?

    /// The recyclable subtree shape, or nil when it did not change.
    public var shape: UInt64?

    /// The sparse or complete change to this element's children.
    public var children: HostChildrenUpdate = .unchanged
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

extension HostPatch {
    init(_ patch: Patch) {
        id = patch.id
        type = patch.type
        replace = patch.replace
        properties = patch.props
        clearedProperties = patch.cleared
        transitions = patch.transitions.mapValues { HostTransition(motion: $0.motion) }
        driven = patch.driven.map { .replace($0.mapValues(HostStateBinding.init)) }
        events = patch.events.map { .replace($0.mapValues { Int32($0) }) }
        motion = patch.motion.map { HostLayoutMotion(motion: $0, lanes: patch.lanes) }
        recycles = patch.recycles
        shape = patch.shape

        let childPatches = patch.children.map(HostPatch.init)
        if patch.arranged {
            children = .arranged(childPatches)
        } else if !childPatches.isEmpty {
            children = .changed(childPatches)
        }
    }
}

extension HostCommand {
    init(_ command: Command) {
        act = command.act
        arguments = command.arguments
        completion = command.completion
    }
}
