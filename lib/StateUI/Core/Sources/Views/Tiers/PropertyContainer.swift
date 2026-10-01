// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The tiers a control's modifiers come from, and the modifiers every view
// shares. Each property is declared once, on the tier whose controls all carry
// it, and a `Style` wears only the property half of each tier.
// Design: docs/design/views/tiers.md#two-halves

/// Anything carrying property values, whether or not it is drawn: a control,
/// a `Style`, a `TextSpan`.
public protocol PropertyContainer {
    /// What a modifier gives back: the control or style itself, so a chain goes
    /// on offering everything it has, or a `ModifiedContent` for a composed view.
    associatedtype Modified = Self

    /// The node being described. Modifiers copy it, change one property, and
    /// return the copy.
    var node: Node { get set }

    /// A copy with one thing changed: the one operation every modifier is
    /// built from.
    func modified(_ change: (inout Node) -> Void) -> Modified
}

extension PropertyContainer {
    /// Sets a property by its token - what the typed `setValue` is written
    /// over, and every modifier that writes a value it built itself.
    func setValue(_ property: Prop, _ value: PropValue) -> Modified {
        modified { $0.props[property] = value }
    }

    /// Sets one of this element's properties to a value of the type its
    /// contract declares.
    ///
    ///     func signal(_ value: TrafficSignal) -> Self {
    ///         setValue(TrafficLightContract.signal, value)
    ///     }
    ///
    /// - Parameters:
    ///   - property: the member, written with its contract.
    ///   - value: what it holds.
    /// - Returns: the element, with the value on it.
    public func setValue<Owner: Contract, Value: HostRepresentable>(
        _ property: ElementProperty<Owner, Value>,
        _ value: Value
    ) -> Modified {
        setValue(property.token, value.propValue)
    }
}

extension PropertyContainer {
    /// A stable name that automation finds this by.
    ///
    ///     Button("Save").accessibilityIdentifier("save")
    ///     ToolbarItem("Home").accessibilityIdentifier("chrome.home")
    ///
    /// Nothing shows it and no screen reader says it: it is the handle a UI
    /// test, a script or an agent asks the platform's automation for. What a
    /// screen-reader user hears is `.accessibilityLabel`. Keep it stable
    /// across renders and unique on the page.
    public func accessibilityIdentifier(_ value: String) -> Modified { setValue(PropertyContainerContract.accessibilityIdentifier, value) }
}

extension PropertyContainer where Modified == Self {
    /// A copy with one property changed. What every modifier on a control or a
    /// style is built from.
    public func modified(_ change: (inout Node) -> Void) -> Self {
        var copy = self
        change(&copy.node)
        return copy
    }
}
