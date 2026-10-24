// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Room that pushes along its stack: it takes the room the stack's other children leave, shared alike with any
/// other space, and none where nothing is left.
///
///     HStack {
///         Text("Draft")
///         Space()
///         Button("Send")
///     }
///
/// The button stands at the row's far end. A space measures as no room of its own, so a stack sized by its
/// children leaves it none; `.minimumWidth` or `.minimumHeight` keeps it a gap at least that long, and a length it
/// states along the stack stops it growing. Being room, it may be drawn: `Space().background(.blur(.thin))` is the
/// rest of a stack made of a blur, in its box's `.shape`, outlined by `.stroke`. Room that takes only what it is
/// offered is a `Fill`.
///
/// Design: docs/design/host/layout.md#a-space
public struct Space: ElementView, BorderElement {
    /// The node this space describes.
    public var node: Node

    /// Room that pushes.
    public init() {
        node = Node(contract: SpaceContract.self)
    }
}
