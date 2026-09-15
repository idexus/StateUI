// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The platform's C maths library, for the drawing matrix's `sin` and `cos`.
#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

// The typed boundary for a host linked into the same Swift process.
//
// A host in this process receives the renderer's sparse patch directly. A host
// across a language boundary receives the Wire encoding of the same model. The
// SPI keeps this machinery out of an application's API while allowing host
// packages maintained beside StateUI to depend on it deliberately.

/// A property value delivered directly to a native Swift host.
@_spi(Host) public typealias HostValue = PropValue

/// Which way a state crosses at a native-host attachment.
@_spi(Host) public typealias HostStateMode = StateMode

/// Which native-host channel carries an attached state.
@_spi(Host) public typealias HostStateKind = StateKind

/// A state image delivered directly to, or reported by, a native Swift host.
@_spi(Host) public typealias HostStateValue = StateCarried

/// The complete image of one host-walked value.
///
/// A native host uses this representation instead of knowing how StateUI lays
/// a journey out in numeric state lanes. Values are arrays because the same
/// channel may carry a number, point, rectangle, insets or colour.
@_spi(Host) public struct HostJourney: Equatable, Sendable {
    /// Where the value stands on the current frame.
    public let value: [Double]

    /// Where the value is travelling.
    public let destination: [Double]

    /// Its current speed per second, lane by lane.
    public let velocity: [Double]

    /// The law carrying it to the destination.
    public let motion: Motion

    /// The continuation waiting for arrival, or nil when nobody waits.
    public let completion: Int?

    /// How many explicit stops this journey has received.
    public let stopped: UInt64

    /// A complete host-side image of a journey.
    public init(
        value: [Double],
        destination: [Double],
        velocity: [Double],
        motion: Motion,
        completion: Int?,
        stopped: UInt64
    ) {
        self.value = value
        self.destination = destination
        self.velocity = velocity
        self.motion = motion
        self.completion = completion
        self.stopped = stopped
    }
}

/// Which parts of a host-walked journey are reported back to StateUI.
@_spi(Host) public struct HostJourneyUpdate: OptionSet, Equatable, Sendable {
    /// The raw option bits.
    public let rawValue: UInt8

    /// Builds an update set from its raw option bits.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Where the value currently stands.
    public static let value = HostJourneyUpdate(rawValue: 1 << 0)

    /// Where the value is travelling.
    public static let destination = HostJourneyUpdate(rawValue: 1 << 1)

    /// How fast the value currently moves.
    public static let velocity = HostJourneyUpdate(rawValue: 1 << 2)

    /// The per-frame report emitted while a host motion is under way.
    public static let frame: HostJourneyUpdate = [.value, .velocity]

    /// The complete position of a journey when it is aimed, stopped or landed.
    public static let position: HostJourneyUpdate = [.value, .destination, .velocity]
}

/// One child placement delivered to a native layout host.
@_spi(Host) public struct HostPlacement: Equatable, Sendable {
    /// The child's rectangle in its layout's coordinates.
    public let bounds: Rect

    /// Horizontal drawing translation from the arranged rectangle.
    public let translationX: Double

    /// Vertical drawing translation from the arranged rectangle.
    public let translationY: Double

    /// Clockwise drawing rotation in degrees.
    public let rotation: Double

    /// Horizontal drawing scale.
    public let scaleX: Double

    /// Vertical drawing scale.
    public let scaleY: Double

    /// Drawing opacity from zero to one.
    public let opacity: Double

    /// Back-to-front rank among siblings.
    public let zIndex: Int

    /// Opacity of the optional shade drawn over the child.
    public let shade: Double
}

extension HostPlacement {
    /// How the placed child is drawn over its rectangle: moved, turned and
    /// sized about the rectangle's centre.
    public var drawing: HostDrawingTransform {
        HostDrawingTransform(
            translationX: translationX,
            translationY: translationY,
            rotation: rotation,
            scaleX: scaleX,
            scaleY: scaleY)
    }
}

/// A complete engine-authored arrangement for one native layout.
@_spi(Host) public struct HostPlacementRun: Equatable, Sendable {
    /// One placement for each child, in child order.
    public let placements: [HostPlacement]

    /// How a changed arrangement travels to its new positions.
    public let motion: Motion
}

/// How a view is drawn over the rectangle its layout gave it.
///
/// Every host draws the same picture from it. Distances are points with y
/// growing down, angles are degrees, and a positive `rotation` turns
/// clockwise. Every part pivots about the anchor, a fraction of the view's
/// size, and the parts apply in one order: the scale, the turn in the plane
/// (`rotation`), the tip about the vertical axis (`rotationY`, which sends
/// the right edge away) and about the horizontal axis (`rotationX`, which
/// sends the top edge away), both seen from `perspectiveDistance`, and last
/// the translation. The drawing changes nothing about the layout: the view
/// keeps its rectangle and only what is drawn moves.
@_spi(Host) public struct HostDrawingTransform: Equatable, Sendable {
    /// Horizontal move, in points.
    public var translationX: Double

    /// Vertical move, in points, downward.
    public var translationY: Double

    /// Clockwise turn in the plane of the screen, in degrees.
    public var rotation: Double

    /// Tip about the horizontal axis, in degrees; positive sends the top away.
    public var rotationX: Double

    /// Turn about the vertical axis, in degrees; positive sends the right edge away.
    public var rotationY: Double

    /// Horizontal size factor.
    public var scaleX: Double

    /// Vertical size factor.
    public var scaleY: Double

    /// The pivot's horizontal position, from 0 at the left edge to 1 at the right.
    public var pivotX: Double

    /// The pivot's vertical position, from 0 at the top edge to 1 at the bottom.
    public var pivotY: Double

    /// A drawing transform; every part left out draws the view as laid out.
    public init(
        translationX: Double = 0,
        translationY: Double = 0,
        rotation: Double = 0,
        rotationX: Double = 0,
        rotationY: Double = 0,
        scaleX: Double = 1,
        scaleY: Double = 1,
        pivotX: Double = 0.5,
        pivotY: Double = 0.5
    ) {
        self.translationX = translationX
        self.translationY = translationY
        self.rotation = rotation
        self.rotationX = rotationX
        self.rotationY = rotationY
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.pivotX = pivotX
        self.pivotY = pivotY
    }

    /// The view drawn exactly where its layout put it.
    public static let identity = HostDrawingTransform()

    /// How far from the screen a tipped view is seen, in points.
    public static let perspectiveDistance = 400.0

    /// Whether the transform draws the view where it was laid out. The
    /// anchor alone moves nothing.
    public var isIdentity: Bool {
        translationX == 0 && translationY == 0
            && rotation == 0 && rotationX == 0 && rotationY == 0
            && scaleX == 1 && scaleY == 1
    }

    /// The transform as one matrix, for a view of the given size, in the
    /// view's own space: the origin at its top left corner.
    public func matrix(width: Double, height: Double) -> HostMatrix {
        let pivotX = pivotX * width
        let pivotY = pivotY * height
        let tips = rotationX != 0 || rotationY != 0

        return HostMatrix.translation(-pivotX, -pivotY)
            * HostMatrix.scale(scaleX, scaleY)
            * HostMatrix.rotation(degrees: rotation, about: .z)
            * HostMatrix.rotation(degrees: rotationY, about: .y)
            * HostMatrix.rotation(degrees: rotationX, about: .x)
            * (tips ? HostMatrix.perspective(Self.perspectiveDistance) : .identity)
            * HostMatrix.translation(pivotX + translationX, pivotY + translationY)
    }
}

/// A 4×4 drawing matrix acting on row vectors: a point (x, y, z, 1) is drawn
/// at (x, y, z, 1)·M divided by its fourth coordinate. `m41` and `m42` move,
/// `m34` carries perspective, and `a * b` applies `a`, then `b`.
@_spi(Host) public struct HostMatrix: Equatable, Sendable {
    /// The first row: where the across axis is drawn.
    public var m11 = 1.0, m12 = 0.0, m13 = 0.0, m14 = 0.0

    /// The second row: where the down axis is drawn.
    public var m21 = 0.0, m22 = 1.0, m23 = 0.0, m24 = 0.0

    /// The third row: where the depth axis is drawn, and its perspective.
    public var m31 = 0.0, m32 = 0.0, m33 = 1.0, m34 = 0.0

    /// The fourth row: the move.
    public var m41 = 0.0, m42 = 0.0, m43 = 0.0, m44 = 1.0

    /// The matrix that draws every point where it is.
    public static let identity = HostMatrix()

    /// `lhs` followed by `rhs`.
    public static func * (lhs: HostMatrix, rhs: HostMatrix) -> HostMatrix {
        let left = lhs.rows
        let right = rhs.rows
        var product = [[Double]](repeating: [0, 0, 0, 0], count: 4)
        for row in 0..<4 {
            for column in 0..<4 {
                var sum = 0.0
                for step in 0..<4 { sum += left[row][step] * right[step][column] }
                product[row][column] = sum
            }
        }
        return HostMatrix(rows: product)
    }

    /// Where the matrix draws a point of the view's plane.
    public func applied(to x: Double, _ y: Double) -> (x: Double, y: Double) {
        let w = x * m14 + y * m24 + m44
        return ((x * m11 + y * m21 + m41) / w, (x * m12 + y * m22 + m42) / w)
    }

    enum Axis { case x, y, z }

    static func translation(_ x: Double, _ y: Double) -> HostMatrix {
        var matrix = HostMatrix()
        matrix.m41 = x
        matrix.m42 = y
        return matrix
    }

    static func scale(_ x: Double, _ y: Double) -> HostMatrix {
        var matrix = HostMatrix()
        matrix.m11 = x
        matrix.m22 = y
        return matrix
    }

    static func rotation(degrees: Double, about axis: Axis) -> HostMatrix {
        guard degrees != 0 else { return .identity }
        let radians = degrees * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)
        var matrix = HostMatrix()
        switch axis {
        case .z:
            matrix.m11 = cosine; matrix.m12 = sine
            matrix.m21 = -sine; matrix.m22 = cosine
        case .x:
            matrix.m22 = cosine; matrix.m23 = sine
            matrix.m32 = -sine; matrix.m33 = cosine
        case .y:
            matrix.m11 = cosine; matrix.m13 = -sine
            matrix.m31 = sine; matrix.m33 = cosine
        }
        return matrix
    }

    static func perspective(_ distance: Double) -> HostMatrix {
        var matrix = HostMatrix()
        matrix.m34 = -1 / distance
        return matrix
    }

    private var rows: [[Double]] {
        [
            [m11, m12, m13, m14],
            [m21, m22, m23, m24],
            [m31, m32, m33, m34],
            [m41, m42, m43, m44],
        ]
    }

    private init(rows: [[Double]]) {
        (m11, m12, m13, m14) = (rows[0][0], rows[0][1], rows[0][2], rows[0][3])
        (m21, m22, m23, m24) = (rows[1][0], rows[1][1], rows[1][2], rows[1][3])
        (m31, m32, m33, m34) = (rows[2][0], rows[2][1], rows[2][2], rows[2][3])
        (m41, m42, m43, m44) = (rows[3][0], rows[3][1], rows[3][2], rows[3][3])
    }

    private init() {}
}

/// Device facts supplied before a native host asks for its first render.
@_spi(Host) public struct HostDeviceInfo: Equatable, Sendable {
    /// The device class used by adaptive application code.
    public let formFactor: FormFactor

    /// The platform's stable public name.
    public let platform: String

    /// The hardware model, where the platform exposes it.
    public let model: String

    /// The hardware manufacturer.
    public let manufacturer: String

    /// The reader-visible device name, where available.
    public let name: String

    /// The operating-system version.
    public let versionString: String

    /// Whether the application runs on hardware or a virtual device.
    public let deviceType: DeviceType

    /// A complete device report.
    public init(
        formFactor: FormFactor,
        platform: String,
        model: String,
        manufacturer: String,
        name: String,
        versionString: String,
        deviceType: DeviceType
    ) {
        self.formFactor = formFactor
        self.platform = platform
        self.model = model
        self.manufacturer = manufacturer
        self.name = name
        self.versionString = versionString
        self.deviceType = deviceType
    }
}

/// Main-display facts supplied by a native host.
@_spi(Host) public struct HostDisplayInfo: Equatable, Sendable {
    /// Display width in physical pixels.
    public let width: Double

    /// Display height in physical pixels.
    public let height: Double

    /// Physical pixels per layout point.
    public let density: Double

    /// The coarse display orientation.
    public let orientation: DisplayOrientation

    /// Rotation from the display's natural orientation.
    public let rotation: DisplayRotation

    /// Frames per second, or zero when the platform does not expose it.
    public let refreshRate: Double

    /// A complete main-display report.
    public init(
        width: Double,
        height: Double,
        density: Double,
        orientation: DisplayOrientation,
        rotation: DisplayRotation,
        refreshRate: Double
    ) {
        self.width = width
        self.height = height
        self.density = density
        self.orientation = orientation
        self.rotation = rotation
        self.refreshRate = refreshRate
    }
}

/// Manifest facts supplied before a native host asks for its first render.
@_spi(Host) public struct HostApplicationInfo: Equatable, Sendable {
    /// The application name shown to the reader.
    public let name: String

    /// The bundle or package identifier.
    public let packageName: String

    /// The reader-visible release version.
    public let versionString: String

    /// The build identifier behind the release version.
    public let buildString: String

    /// A complete application report.
    public init(
        name: String,
        packageName: String,
        versionString: String,
        buildString: String
    ) {
        self.name = name
        self.packageName = packageName
        self.versionString = versionString
        self.buildString = buildString
    }
}

/// One state channel attached to a native property.
@_spi(Host) public struct HostStateBinding: Equatable, Sendable {
    /// The channel number quoted back to StateUI by a host.
    public let state: Int32

    /// Which direction the value crosses.
    public let mode: HostStateMode

    /// Which native-host channel carries the value.
    public let kind: HostStateKind

    /// One attachment between a state channel and a native property.
    public init(state: Int32, mode: HostStateMode, kind: HostStateKind) {
        self.state = state
        self.mode = mode
        self.kind = kind
    }
}

/// One state value published by a completed host cycle.
@_spi(Host) public struct HostStateChange: Equatable, Sendable {
    /// The state channel whose value changed.
    public let state: Int32

    /// The lanes that changed, or every bit for text.
    public let changed: UInt64

    /// The complete value after the cycle.
    public let value: HostStateValue

    /// One sparse state change published at the end of a host cycle.
    public init(state: Int32, changed: UInt64, value: HostStateValue) {
        self.state = state
        self.changed = changed
        self.value = value
    }
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
    /// which no host-neutral operation can put back - a member that says it is
    /// not `cleared`, and nothing else. Every other lost property is named in `clearedProperties`
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

/// One act the application called, for a native host to perform.
///
/// The application calls through `stateUICall` or `stateUISend`. The host
/// takes the call with `StateUIHost.takeActCalls()` and answers one that
/// carries a completion with `StateUIHost.reply(_:with:)` or
/// `StateUIHost.fail(_:reason:)`.
@_spi(Host) public struct HostActCall: Sendable {
    /// The act's token.
    public let act: Act

    /// Typed arguments, in the order the act declares them.
    public let arguments: [HostValue]

    /// The negative id the answer quotes back, or nil when nobody waits.
    public let completion: Int?
}

/// Operations a native Swift host performs on the StateUI runtime.
@_spi(Host) public enum StateUIHost {
    /// Whether state changed since the last render.
    public static var needsRender: Bool { Renderer.shared.needsRender }

    /// Updates the appearance used to resolve themed values before rendering.
    public static func setTheme(_ theme: Theme) {
        StandardEnvironment.app.requestedTheme = theme
    }

    /// Replaces the standard device report used by application builds.
    public static func setDeviceInfo(_ info: HostDeviceInfo) {
        let device = StandardEnvironment.device
        device.formFactor = info.formFactor
        device.platform = info.platform
        device.model = info.model
        device.manufacturer = info.manufacturer
        device.name = info.name
        device.versionString = info.versionString
        device.deviceType = info.deviceType
    }

    /// Replaces the standard main-display report used by application builds.
    public static func setDisplayInfo(_ info: HostDisplayInfo) {
        let display = StandardEnvironment.display
        display.width = info.width
        display.height = info.height
        display.density = info.density
        display.orientation = info.orientation
        display.rotation = info.rotation
        display.refreshRate = info.refreshRate
    }

    /// Replaces the standard application-manifest report used by builds.
    public static func setApplicationInfo(_ info: HostApplicationInfo) {
        let app = StandardEnvironment.app
        app.name = info.name
        app.packageName = info.packageName
        app.versionString = info.versionString
        app.buildString = info.buildString
    }

    /// Hands a platform-created scene to StateUI before its first render.
    ///
    /// The first call claims the scene prepared when the application was
    /// registered. Every later call creates another independent scene. Values
    /// restored by the platform land before that scene builds, so
    /// `@State(sceneKey:)` never briefly exposes its declared default.
    public static func connectScene(restoring values: [String: HostValue] = [:]) {
        Scenes.shared.connected(restoring: values)
    }

    /// Updates the process-wide application session from native lifecycle.
    public static func setApplicationPhase(_ phase: ApplicationPhase) {
        StandardEnvironment.application.phase = phase
    }

    /// The platform store selected by the registered application.
    public static var persistentStorage: PersistentStorage {
        StandardEnvironment.application.persistentStorage
    }

    /// The typed keys the host reads before the first application render.
    public static var persistentKeys: [PersistentKey] {
        StandardEnvironment.application.persistentKeys
    }

    /// Hydrates values found in the native store before the first render.
    public static func restorePersistent(_ values: [String: HostValue]) {
        PersistentStore.shared.hydrate(
            values.sorted { $0.key < $1.key }.map { (name: $0.key, value: $0.value) })
    }

    /// Decodes a complete property-state image for a native motion channel.
    ///
    /// Returns nil for text, plain values, feeds, placement runs and malformed
    /// images. The lane layout remains an implementation detail of StateUI.
    public static func journey(from value: HostStateValue) -> HostJourney? {
        guard case .lanes(let lanes) = value else { return nil }

        let remainder = lanes.count - StateLaw.lanes - 2
        guard remainder > 0, remainder.isMultiple(of: 3) else { return nil }

        let width = remainder / 3
        let lawStart = width * 3
        let completionLane = lanes[lawStart + StateLaw.lanes]
        let stopped = lanes[lawStart + StateLaw.lanes + 1]
        guard lanes.allSatisfy(\.isFinite),
              let completion = Int(exactly: completionLane),
              let stoppedCount = UInt64(exactly: stopped)
        else { return nil }

        return HostJourney(
            value: Array(lanes[0..<width]),
            destination: Array(lanes[width..<(width * 2)]),
            velocity: Array(lanes[(width * 2)..<(width * 3)]),
            motion: StateLaw.motion(
                of: Array(lanes[lawStart..<(lawStart + StateLaw.lanes)])),
            completion: completion == 0 ? nil : completion,
            stopped: stoppedCount)
    }

    /// Encodes a typed journey as the complete state image a host applies.
    public static func value(of journey: HostJourney) -> HostStateValue {
        .lanes(
            journey.value
                + journey.destination
                + journey.velocity
                + StateLaw.lanes(of: journey.motion)
                + [Double(journey.completion ?? 0), Double(journey.stopped)])
    }

    /// Decodes an engine-authored arrangement without exposing its lane layout.
    public static func placements(from value: HostStateValue) -> HostPlacementRun? {
        guard let run = PlacedRun(carried: value) else { return nil }

        return HostPlacementRun(
            placements: run.placements.map {
                HostPlacement(
                    bounds: $0.bounds,
                    translationX: $0.transform.x,
                    translationY: $0.transform.y,
                    rotation: $0.transform.rotation,
                    scaleX: $0.transform.width,
                    scaleY: $0.transform.height,
                    opacity: $0.opacity,
                    zIndex: $0.zIndex,
                    shade: $0.shade)
            },
            motion: run.motion)
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

    /// Reads where a one-lane state named directly by `panX` or `panY` stands.
    public static func gestureValue(state: Int32) -> Double? {
        Renderer.shared.hostGestureValue(state: state)
    }

    /// Moves the first lane of a state named directly by a native gesture.
    /// The host advances its StateUI cycle immediately after this write.
    @discardableResult
    public static func moveGestureValue(_ value: Double, state: Int32) -> Bool {
        Renderer.shared.hostMovedGesture(value, state: state)
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

    /// Reports the host-owned position of a moving property state.
    ///
    /// A frame normally updates only `value` and `velocity`. Aiming, stopping
    /// and landing also update `destination`, keeping the journey's three
    /// numerical groups coherent without exposing their lane layout.
    ///
    /// - Parameters:
    ///   - journey: The complete journey after the host-side change.
    ///   - update: The numerical groups the host changed.
    ///   - binding: Any inward-capable property attachment on this state.
    /// - Returns: Whether the current attachment accepted the report.
    @discardableResult
    public static func report(
        _ journey: HostJourney,
        updating update: HostJourneyUpdate,
        through binding: HostStateBinding
    ) -> Bool {
        Renderer.shared.hostReported(journey, updating: update, through: binding)
    }

    /// Completes an awaited journey after its host motion ends or is replaced.
    ///
    /// - Parameters:
    ///   - completion: The negative continuation id carried by the journey.
    ///   - succeeded: Whether the journey reached its destination.
    /// - Returns: Whether a continuation still waited under that id.
    @discardableResult
    public static func complete(_ completion: Int, succeeded: Bool) -> Bool {
        guard completion < 0 else { return false }
        ReplyBuffer.current = .finished([.bool(succeeded)])
        return Renderer.shared.dispatch(completion)
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

    /// Raises an event of the application's - one no control raises - with
    /// the values its contract declares, as the platform reported them: every
    /// `HostEvents.on` subscription to the member hears them, each handler
    /// queued on this library's executor for the next `runJobs`. The road a
    /// foreign host's raise takes through the export, typed at the call: the
    /// values are the member's, so a raise of another shape does not compile.
    ///
    ///     StateUIHost.raise(GalleryContract.batteryChanged, level, charging)
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - value: what it carries, in the order its contract declares.
    /// - Returns: how many subscriptions heard it - a raise nobody hears is
    ///   an ordinary zero.
    @discardableResult
    public static func raise<Owner: ApplicationTier, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        _ value: repeat each Value
    ) -> Int {
        HostEvents.dispatch(event.token.name, MemberValues.encode(repeat each value))
    }

    /// Tells the core what this host realizes - its `Registry.realization`,
    /// or what a host across the Wire reported - replacing what it said
    /// before. Until a host says, the core knows of nothing realized.
    ///
    /// - Parameter realization: the elements and members this host realizes.
    public static func setRealization(_ realization: HostRealization) {
        HostRealizations.current = realization
    }

    /// Whether this host makes a view for an element.
    ///
    /// - Parameter contract: the element's contract.
    /// - Returns: whether the host said it realizes the element.
    public static func realizes(_ contract: any ElementContract.Type) -> Bool {
        HostRealizations.current.elements.contains(contract.nodeType.name)
    }

    /// Whether this host realizes a property, on any element.
    ///
    /// - Parameter member: the property, written with its contract.
    /// - Returns: whether the host said it realizes the property.
    public static func realizes<Owner: Contract, Value>(_ member: ElementProperty<Owner, Value>) -> Bool {
        HostRealizations.current.members.contains { $0.owner == Owner.name && $0.member == member.name }
    }

    /// Whether this host raises an event, on any element.
    ///
    /// - Parameter member: the event, written with its contract.
    /// - Returns: whether the host said it raises the event.
    public static func realizes<Owner: Contract, Payload>(_ member: ElementEvent<Owner, Payload>) -> Bool {
        HostRealizations.current.members.contains { $0.owner == Owner.name && $0.member == member.name }
    }

    /// Runs jobs waiting on StateUI's UI executor on the calling thread.
    @discardableResult
    public static func runJobs() -> Int { stateUIRunJobs() }

    /// Parks the calling doorbell thread until asynchronous work arrives.
    public static func waitForWork() -> Int {
        MainThreadExecutor.shared.waitForWork()
            + Renderer.shared.actCallsPending
            + (Renderer.shared.needsRender ? 1 : 0)
    }

    /// Takes the act calls queued since the previous host pump, in the order
    /// the application made them.
    public static func takeActCalls() -> [HostActCall] {
        Renderer.shared.takeActCalls().map(HostActCall.init)
    }

    /// Answers a performed act call with the values it came to.
    ///
    /// The awaiting `stateUICall` resumes with exactly these values - none
    /// for an act that returns nothing.
    ///
    /// - Parameters:
    ///   - completion: The negative id the act call carried.
    ///   - values: What the act came to, in the order it declares them.
    /// - Returns: Whether a caller still waited under that id.
    @discardableResult
    public static func reply(_ completion: Int, with values: [HostValue]) -> Bool {
        guard completion < 0 else { return false }
        ReplyBuffer.current = .finished(values)
        return Renderer.shared.dispatch(completion)
    }

    /// Fails an act call the host could not perform.
    ///
    /// The awaiting `stateUICall` throws `StateUIError` carrying `reason`.
    ///
    /// - Parameters:
    ///   - completion: The negative id the act call carried.
    ///   - reason: Why the host could not perform it.
    /// - Returns: Whether a caller still waited under that id.
    @discardableResult
    public static func fail(_ completion: Int, reason: String) -> Bool {
        guard completion < 0 else { return false }
        ReplyBuffer.current = .failed(reason)
        return Renderer.shared.dispatch(completion)
    }
}

extension HostStateBinding {
    init(_ entry: StateEntry) {
        state = entry.number
        mode = entry.mode
        kind = entry.kind
    }
}

extension HostActCall {
    init(_ call: ActCall) {
        act = call.act
        arguments = call.arguments
        completion = call.completion
    }
}
