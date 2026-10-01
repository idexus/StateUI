// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

/// A pin on the map.
///
///     Pin("Royal Castle")
///         .address("Plac Zamkowy 4")
///         .location(latitude: 52.2479, longitude: 21.0155)
///
/// Tapping the pin shows its label and address in the platform's own
/// callout; `.onPinClicked` is the tap on the pin, `.onPinDetailsClicked`
/// the tap on that callout - its details.
public struct Pin: Element {
    /// The node this pin describes.
    public var node: Node

    /// A pin labelled `label` - what the callout shows in bold. Give it a
    /// `.location`, or it stands at zero-zero in the Atlantic.
    public init(_ label: String) {
        node = Node(contract: PinContract.self)
        node.write(PinContract.label, label)
    }

    /// The node, as every element answers it.
    public var body: Node { node }

    /// The callout's first line, in bold. The initializer takes the same
    /// value and is where a pin usually gets it.
    public func label(_ value: String) -> Self {
        var copy = self
        copy.node.write(PinContract.label, value)
        return copy
    }

    /// The line under the label in the callout.
    public func address(_ value: String) -> Self {
        var copy = self
        copy.node.write(PinContract.address, value)
        return copy
    }

    /// What the pin stands for, which is what decides the icon the platform
    /// draws for it.
    public func type(_ value: PinType) -> Self {
        var copy = self
        copy.node.write(PinContract.type, value)
        return copy
    }

    /// Where it stands.
    public func location(latitude: Double, longitude: Double) -> Self {
        var copy = self
        copy.node.write(PinContract.location, Location(latitude: latitude, longitude: longitude))
        return copy
    }

    /// Fires when the pin is tapped. Observing only: it cannot keep the
    /// callout shut.
    public func onPinClicked(_ handler: @escaping EventHandler) -> Self {
        var copy = self
        copy.node.addHandler(PinContract.pinClicked, handler)
        return copy
    }

    /// Fires when the callout above the pin - its details - is tapped: the
    /// place a navigation usually goes.
    public func onPinDetailsClicked(_ handler: @escaping EventHandler) -> Self {
        var copy = self
        copy.node.addHandler(PinContract.pinDetailsClicked, handler)
        return copy
    }
}
