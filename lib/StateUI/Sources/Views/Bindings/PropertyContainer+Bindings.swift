// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension PropertyContainer {
    /// Carries one of this element's properties from a state the host keeps,
    /// the state's value being the type the contract declares - how an
    /// application's own control takes a binding for a property.
    ///
    /// Write it on the control, never on its `…Properties` protocol, which a
    /// `Style` wears too.
    ///
    /// - Parameters:
    ///   - property: the member, written with its contract.
    ///   - state: the whole state, `$x`, of a `@State` or a `@Binding`. A part
    ///     of one, `$room.width`, cannot be carried and is refused.
    ///   - mode: which way the value crosses.
    ///   - kind: how the host applies the value; see `StateKind`.
    /// - Returns: the element, with the registration on it.
    public func setValue<Owner: Contract, Value: HostRepresentable & StateValue>(
        _ property: ElementProperty<Owner, Value>,
        on state: Binding<Value>,
        mode: StateMode,
        kind: StateKind
    ) -> Modified {
        setValue(property.token, on: state, mode: mode, kind: kind)
    }

    /// The same, for a value the host can animate - a number, a colour, a
    /// thickness, a point. With `kind: .property` the host animates the
    /// property along the state's journey, so `$stars.journey.move(to: 5)`
    /// moves it; any other kind carries the value as it stands.
    ///
    ///     func rating(_ state: Binding<Double>) -> Modified {
    ///         setValue(RatingBarContract.rating, on: state, mode: .inOut, kind: .property)
    ///     }
    ///
    /// - Parameters:
    ///   - property: the member, written with its contract.
    ///   - state: the whole state, `$x`.
    ///   - mode: which way the value crosses.
    ///   - kind: how the host applies the value; see `StateKind`.
    /// - Returns: the element, with the registration on it.
    public func setValue<Owner: Contract, Value: HostRepresentable & Walked>(
        _ property: ElementProperty<Owner, Value>,
        on state: Binding<Value>,
        mode: StateMode,
        kind: StateKind
    ) -> Modified {
        setValue(property.token, on: state, mode: mode, kind: kind)
    }

    /// Writes the number of a carried state onto a property - how a drag is
    /// told where to report (`panX`, `panY`). It reads nothing at build, so
    /// the reports rebuild nothing.
    func driven<Value: StateValue>(_ property: Prop, by state: Binding<Value>) -> Modified {
        guard let image = state.image else {
            complain("`\(property.name)` was told to report into a part of a state, or a "
                + "binding made from closures, which the host cannot carry. Report "
                + "into the whole state.")
            return modified { _ in }
        }

        return setValue(property, .number(Double(Renderer.shared.number(for: image))))
    }

    /// Carries a property from a state by its token - what the typed
    /// `setValue(_:on:mode:kind:)` and every driven modifier are written over.
    /// Design: docs/design/views/bindings.md#the-image-never-the-value
    func setValue<Value: StateValue>(
        _ property: Prop,
        on state: Binding<Value>,
        mode: StateMode,
        kind: StateKind
    ) -> Modified {
        // The image, never the value: nothing is read at build.
        guard let image = state.image else {
            complain("`\(property.name)` was driven from a part of a state, or a binding "
                + "made from closures, which the host cannot carry. Drive it from "
                + "the whole state.")
            return modified { _ in }
        }

        state.described?.wearThemedPair()

        return modified {
            $0.driven[property] = StateRegistration(
                state: image,
                conversion: state.conversion,
                mode: mode,
                kind: kind,
                values: property.facts.moves.union(Value.moving),
                current: { state.wrappedValue.carried })
        }
    }

    /// The same for a value the host can animate, by its token: `.property`
    /// carries it as a journey, any other kind as itself.
    func setValue<Value: Walked>(
        _ property: Prop,
        on state: Binding<Value>,
        mode: StateMode,
        kind: StateKind
    ) -> Modified {
        guard kind == .property else {
            guard let image = state.image else {
                complain("`\(property.name)` was driven from a part of a state, or a binding "
                    + "made from closures, which the host cannot carry. Drive it from "
                    + "the whole state.")
                return modified { _ in }
            }

            state.described?.wearThemedPair()

            return setValue(property, onImage: image, mode: mode, kind: kind,
                            moving: Value.moving, conversion: state.conversion)
        }

        guard let image = state.journeyImage else {
            complain("`\(property.name)` was handed a part of a state, a binding made from "
                + "closures, or a state the host already carries in another shape, "
                + "none of which it can walk. Hand it the whole state.")
            return modified { _ in }
        }

        state.described?.wearThemedPair()

        return setValue(property, onImage: image, mode: mode, kind: kind,
                        moving: JourneyLanes<Value>.moving, conversion: state.conversion)
    }

    /// The same registration over an image already made; `moving` says which
    /// lanes the value animates in - a journey's, for a carried `Double`.
    func setValue(
        _ property: Prop,
        onImage image: HostStorage,
        mode: StateMode,
        kind: StateKind,
        moving: MotionValues,
        conversion: Conversion? = nil
    ) -> Modified {
        modified {
            $0.driven[property] = StateRegistration(
                state: image,
                conversion: conversion,
                mode: mode,
                kind: kind,
                values: property.facts.moves.union(moving))
        }
    }

    /// A property the host animates from a state - what every binding twin of
    /// an animatable value, a slider's thumb and a scroller's offset are
    /// written over.
    /// Design: docs/design/views/bindings.md#binding-twins
    func journey<Value: Walked>(_ property: Prop, by state: Binding<Value>) -> Modified {
        guard let image = state.journeyImage else {
            complain("`\(property.name)` was handed a part of a state, a binding made from "
                + "closures, or a state the host already carries in another shape, "
                + "none of which it can walk. Hand it the whole state, declared for "
                + "it.")
            return modified { _ in }
        }

        state.described?.wearThemedPair()

        return setValue(property, onImage: image, mode: .inOut, kind: .property,
                        moving: JourneyLanes<Value>.moving, conversion: state.conversion)
    }

    /// A property the host sets as the state's value stands, with no animation;
    /// `.inOut` where the control reports it back, as a switch does.
    func plain<Value: StateValue>(_ property: Prop, by state: Binding<Value>, mode: StateMode = .out) -> Modified {
        setValue(property, on: state, mode: mode, kind: .plain)
    }

    /// Text the host writes into a property as the state changes; `.inOut`
    /// where the user types into it.
    func words(_ property: Prop, by state: Binding<String>, mode: StateMode = .out) -> Modified {
        setValue(property, on: state, mode: mode, kind: .text)
    }

    /// `journey(_:by:)` over a member of the type its contract declares.
    func journey<Owner: Contract, Value: Walked & HostRepresentable>(
        _ property: ElementProperty<Owner, Value>,
        by state: Binding<Value>
    ) -> Modified {
        journey(property.token, by: state)
    }

    /// `plain(_:by:mode:)` over a member of the type its contract declares.
    func plain<Owner: Contract, Value: StateValue & HostRepresentable>(
        _ property: ElementProperty<Owner, Value>,
        by state: Binding<Value>,
        mode: StateMode = .out
    ) -> Modified {
        plain(property.token, by: state, mode: mode)
    }

    /// `words(_:by:mode:)` over a text member.
    func words<Owner: Contract>(
        _ property: ElementProperty<Owner, String>,
        by state: Binding<String>,
        mode: StateMode = .out
    ) -> Modified {
        words(property.token, by: state, mode: mode)
    }
}
