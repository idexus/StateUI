// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Empty room that grows along its stack: it takes the room the stack's other children leave, shared alike with
/// any other spacer, and none where nothing is left.
///
///     HStack {
///         Text("Draft")
///         Spacer()
///         Button("Send")
///     }
///
/// The button stands at the row's far end. A spacer measures as no room of its own, so a stack sized by its
/// children leaves it none; `.minimumWidth` or `.minimumHeight` keeps it a gap at least that long.
///
/// Design: docs/design/host/layout.md#a-spacer
public struct Spacer: ElementView {
    /// The node this spacer describes.
    public var node: Node

    /// Room that grows.
    public init() {
        node = Node(contract: SpacerContract.self)
    }
}
