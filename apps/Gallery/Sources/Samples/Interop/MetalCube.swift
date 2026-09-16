#if APPKIT
// A control of the application's OWN that draws with the GPU, declared for the
// one host that can realize it.
//
// Every other element here is declared for all of them: a contract and a
// `View`, shared, with each host saying what it IS on screen. This one is
// declared under a condition, because the view behind it is an `MTKView` and
// Metal belongs to this platform. `GalleryElements` lists it under the same
// condition, so no other host is held to a promise it cannot keep.
//
// PUBLIC, because a host in the same process registers BY TYPE and lives in a
// module of its own - see GalleryContract.swift.

import StateUI

/// What colour the cube is painted.
///
/// A closed vocabulary, so it crosses as its member's number, and the host's
/// registration is handed it back as a `CubeColor` rather than as that number.
public enum CubeColor: Int32, CaseIterable, HostRepresentable {
    /// Teal.
    case teal = 0

    /// Amber.
    case amber = 1

    /// Violet.
    case violet = 2
}

/// The gallery's own Metal cube, declared: its node type, the tier it wears,
/// and its members, each with its value's type.
public enum MetalCubeContract: ElementContract {
    public static let nodeType: NodeType = "Gallery.MetalCube"
    public static let tiers: [any Contract.Type] = [ViewContract.self]

    /// How long the cube's edge is, as a share of the room the view is given,
    /// 0 through 1. A size HAS a half way, so a change travels and a walk of
    /// it is a cube that grows.
    public static let size = ElementProperty<Self, Double>("size")

    /// Which colour the cube is painted. A vocabulary has no half way, so a
    /// change does not travel.
    public static let color = ElementProperty<Self, CubeColor>("color", travels: false)

    /// Whether the cube turns. Stopped, it holds the angle it had.
    public static let isSpinning = ElementProperty<Self, Bool>("isSpinning", travels: false)

    public static let members: [any ContractMember] = [size, color, isSpinning]
}

/// A cube drawn on the GPU by a control the application registered with its
/// host, described here like a built-in one.
///
/// Nothing about the drawing is described here and nothing about the
/// description is drawn here: this side owns what the cube should be, and the
/// host owns the frames that make it so.
public struct MetalCube: View {
    public var node = Node(contract: MetalCubeContract.self)

    /// A cube at whatever size, colour and motion its modifiers say.
    public init() {}

    /// How long the cube's edge is, as a share of the room the view is given,
    /// 0 through 1.
    public func size(_ value: Double) -> Self {
        setValue(MetalCubeContract.size, value)
    }

    /// Which colour the cube is painted.
    public func color(_ value: CubeColor) -> Self {
        setValue(MetalCubeContract.color, value)
    }

    /// Whether the cube turns.
    public func isSpinning(_ value: Bool) -> Self {
        setValue(MetalCubeContract.isSpinning, value)
    }
}
#endif
