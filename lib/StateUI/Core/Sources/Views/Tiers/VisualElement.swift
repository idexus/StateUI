// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A control backed by a node, and drawn.
public protocol VisualElement: ModifiableElement, VisualElementProperties, AutomationElement {}

/// The properties every drawn control has: the value half of
/// `VisualElement`, shared by the control and its `Style`.
public protocol VisualElementProperties: PropertyContainer {}

extension VisualElement {
    /// How this view's values animate when they change.
    ///
    ///     VStack { … }.motion(.spring(response: .milliseconds(260)))
    ///     Text(count).motion(.none)
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
    ///         .motion(.spring(response: .milliseconds(240)))
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
    /// existing controls instead of rewriting each into its neighbor:
    ///
    ///     VStack {
    ///         ForEach(items, id: \.id) { item in
    ///             Text(item.title)           // key from the loop
    ///         }
    ///
    ///         if showingTotal {
    ///             Text("Total").id("total")  // key written by hand
    ///         }
    ///     }
    ///
    /// An `.id()` written on the view wins over the one `ForEach` gives. Any
    /// `Hashable` is a key - a string, a number, a UUID, the author's own enum,
    /// struct or class - compared as the value it is; one written twice among
    /// siblings is said.
    ///
    /// An id is who a view is, not what it is drawn as: two views drawn as
    /// one as one leaves and the other comes share a `transitionID(_:)`.
    ///
    /// - Parameter value: who this view is - distinct among its siblings and
    ///   the same across renders.
    public func id(_ value: some Hashable) -> Modified {
        modified { node in node.identify(value) }
    }

    /// Puts an aim on this control, which is how an act reaches it.
    ///
    ///     @Aim(TextField.self) private var field
    ///
    ///     TextField($address).aim(field)
    ///     Button("Edit").onClicked(policy: .ignoreWhileRunning) { try await field.focus() }
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

    /// Copies where the host shows a state into a state of your own, at most
    /// so many times a second.
    ///
    ///     @State private var fade = 1.0
    ///     @State private var shown = 1.0
    ///
    ///     VStack {
    ///         Text("\(Int(shown * 100))%")
    ///     }
    ///     .opacity($fade)
    ///     .samples($fade.journey, into: $shown, .every(.milliseconds(100)))
    ///
    /// Reading `fade` answers where it is going, and `$fade.journey.sample` in
    /// a body rebuilds that body on every frame; this copies some of those
    /// frames into an ordinary state instead. It stops when the value lands,
    /// the last one copied being where it ended. While its view stands the
    /// reading is a consumer of the journey. The target may not be the source,
    /// nor a state the source is derived from.
    ///
    /// - Parameters:
    ///   - source: the journey to read, `$x.journey` of a `@State`.
    ///   - target: the state to read it into, `$y`.
    ///   - cadence: how often, at most.
    /// - Returns: the element, with that reading asked for.
    public func samples<Value: Walked>(
        _ source: Journey<Value>,
        into target: Binding<Value>,
        _ cadence: Cadence
    ) -> Modified {
        modified {
            let from = source.storage, into = target.storage

            // A reading into its own source, or a state its source goes back to, would feed itself.
            guard into !== from, from.conversion?.chain.flatMap(\.sources).contains(where: { $0 === into }) != true
            else {
                complain("`.samples` was asked to read `\(from.origin ?? "a state")` into itself or into a state "
                    + "it is derived from, which would feed the reading its own writes. Read it into another "
                    + "state, or follow the journey with an engine.")
                return
            }

            $0.samples.append((source: JourneyConsumer(of: source), into: ObjectIdentifier(into), cadence: cadence, take: {
                // Off the image, not the journey's own read: the element being built is no reader of it.
                guard let now = from.image?.sample?.typed(Value.self, at: 0)?.value,
                      StateImage.bytes(of: now.carried(in: .current))
                        != StateImage.bytes(of: into.value.carried(in: .current))
                else { return }

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
    /// branch. A `Localization` also says the language the branch's words are
    /// in; a change of that language reaches the branch, not the provider.
    public func environment<Value: AnyObject>(_ object: Value) -> Modified {
        modified {
            $0.environments.append((key: ObjectIdentifier(Value.self), object: object))
            $0.sayLanguage(of: [(key: ObjectIdentifier(Value.self), object: object)])
        }
    }
}


