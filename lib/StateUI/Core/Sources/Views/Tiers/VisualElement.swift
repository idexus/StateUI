// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A control backed by a node, and drawn.
public protocol VisualElement: ModifiableElement, VisualElementProperties {}

/// The properties every drawn control has: the value half of
/// `VisualElement`, shared by the control and its `Style`.
public protocol VisualElementProperties: PropertyContainer {}

extension VisualElement {
    /// How this view's values animate when they change.
    ///
    ///     VStack { … }.motion(.spring(response: 260))
    ///     Label(count).motion(.none)
    ///
    /// A changed value animates to its new setting by default; `.none` snaps,
    /// which is what a value rewritten every frame wants. It applies to this
    /// view only, not to the views inside it; `application.motion` sets the
    /// whole application.
    ///
    /// - Parameter motion: how its values animate.
    /// - Returns: the view, with the motion on it.
    public func motion(_ motion: Motion) -> Modified {
        modified { node in
            var plan = node.motion ?? MotionPlan(base: nil)
            plan.base = motion
            node.motion = plan
        }
    }

    /// How some of this view's values animate, leaving the rest as they were.
    ///
    ///     VStack { … }
    ///         .motion(.spring(response: 240))
    ///         .motion(.none, .size)
    ///
    /// The last rule that names a value answers for it. The usual use is a view
    /// whose shape changes: it takes its new size at once while still
    /// animating to its new place.
    ///
    /// - Parameters:
    ///   - motion: how those values animate.
    ///   - values: which of them. See `MotionValues` for what each name covers.
    /// - Returns: the view, with the rule on it.
    public func motion(_ motion: Motion, _ values: MotionValues) -> Modified {
        modified { node in
            var plan = node.motion ?? MotionPlan(base: nil)
            plan.rules.append((values: values, motion: motion))
            node.motion = plan
        }
    }

    /// Who this view is among its siblings: its key across renders.
    ///
    /// A view that comes back with the same key keeps its control, and only the
    /// properties that changed are written to it. Give one to anything whose
    /// position can change, so inserting, removing or reordering moves the
    /// existing controls instead of rewriting each into its neighbour:
    ///
    ///     VStack {
    ///         ForEach(items, id: \.id) { item in
    ///             Label(item.title)           // key from the loop
    ///         }
    ///
    ///         if showingTotal {
    ///             Label("Total").id("total")  // key written by hand
    ///         }
    ///     }
    ///
    /// An `.id()` written on the view wins over the one `ForEach` gives. Any
    /// `Hashable` is a key - a string, a number, a UUID, the author's own enum
    /// or struct - compared as `String(describing:)`: a description that says
    /// less than the value gives two values one key, and a class is keyed by
    /// something it holds (`.id(file.path)`).
    ///
    /// - Parameter value: who this view is - distinct among its siblings and
    ///   the same across renders.
    public func id(_ value: some Hashable) -> Modified {
        modified { $0.id = String(describing: value) }
    }

    /// Puts an aim on this control, which is how an act reaches it.
    ///
    ///     @Aim(TextField.self) private var field
    ///
    ///     TextField($address).aim(field)
    ///     Button("Edit").onClicked { try await field.focus() }
    ///
    /// A model may declare its aims beside its state. An aim is not a key: a
    /// view carrying only an aim is still matched by where it was written, so
    /// rows keep wanting `.id()`, and the two compose - `.id("row-7").aim(row)`.
    /// On a composed view, write it directly on the initializer's result.
    ///
    /// - Parameter aim: the aim the control answers to.
    public func aim(_ aim: Aim<Self>) -> Modified {
        modified { $0.aim = aim.box }
    }

    /// Reads where a value the host is animating has got to, at most so many
    /// times a second, into a state of your own.
    ///
    ///     @State private var fade = 1.0
    ///     @State private var shown = 1.0
    ///
    ///     VStack {
    ///         Label("\(Int(shown * 100))%")
    ///     }
    ///     .opacity($fade)
    ///     .samples($fade, into: $shown, .every(100))
    ///
    /// Reading `fade` answers where it is going, and `$fade.journey.value` in a
    /// body rebuilds that body on every frame; this copies some of those frames
    /// into an ordinary state instead. It stops when the value lands, the last
    /// sample being where the value ended. A value that is only shown wants a
    /// driven text (`Label($fade.journey.convert { … })`), which costs no render.
    ///
    /// - Parameters:
    ///   - source: the value the host is animating, `$x` of a `@State`.
    ///   - target: the state to read it into, `$y`.
    ///   - asks: how often, at most.
    /// - Returns: the element, with that reading asked for.
    public func samples<Value: Walked>(
        _ source: Binding<Value>,
        into target: Binding<Value>,
        _ asks: Asks
    ) -> Modified {
        modified {
            guard let from = source.described, let image = from.walkedImage(),
                  let into = target.described
            else {
                complain("`.samples` was given a binding that borrows no @State the host "
                    + "walks - a closure binding, a part of a state, or a state carried as "
                    + "the value itself - so there is no journey to read. Hand it the "
                    + "state itself.")
                return
            }

            $0.samples.append((image: image, into: ObjectIdentifier(into), asks: asks, take: {
                // Off the lanes, not the journey's own read, so the element being
                // built does not become a reader of the value.
                guard let now = from.journeyLanes?.value else { return }

                guard StateImage.bytes(of: now.carried)
                    != StateImage.bytes(of: into.value.carried) else { return }

                target.wrappedValue = now
            }))
        }
    }

    /// Provides an object to this view and everything under it, resolved by
    /// type: any view below declaring `@Environment var context: MyContext`
    /// reads the nearest `MyContext` provided above it. A nearer
    /// `.environment()` of the same type overrides for its own branch.
    ///
    ///     @State var context = MyContext()   // a class of @State properties, usually
    ///
    ///     ChildView()
    ///         .environment(context)
    ///
    /// Providing reads no property, so a change in the object rebuilds the
    /// readers below and not the provider; replacing the object rebuilds the
    /// branch.
    public func environment<Value: AnyObject>(_ object: Value) -> Modified {
        modified { $0.environments.append((key: ObjectIdentifier(Value.self), object: object)) }
    }

    /// The keyed style from the application's style sheet that this view wears.
    ///
    ///     Label("Welcome").style("Headline")
    ///
    /// A style without a key applies to every control of its type by itself.
    public func style(_ key: String) -> Modified { setValue(VisualElementContract.style, Name(key)) }
}

extension VisualElement {
    /// Whether the platform has given this control the focus, written into the
    /// binding. Read-only: the platform moves the focus.
    public func isFocused(_ binding: Binding<Bool>) -> Modified {
        onEvent(VisualElementContract.isFocusedChanged) { focused in
            binding.wrappedValue = focused
        }
    }

}
