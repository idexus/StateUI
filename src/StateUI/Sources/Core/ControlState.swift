// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A CONTROL, HELD IN STATE: how an act reaches a view.
//
// The tree describes what the interface IS; an act - putting the keyboard on a
// field, scrolling a list, stepping back through a WebView's history - has to
// say WHICH control it is about, and a description rebuilt every render has no
// object to point at. What survives a render is the element's IDENTITY, and a
// `ControlState` is that identity held in state:
//
//     @State private var browser = ControlState<WebView>()
//
//     WebView(address).assign(browser)
//     Button("Back").onClicked { try await browser.goBack() }
//
// EVERYTHING AN AUTHOR HOLDS IS `@State`, and there are two kinds of it: a
// VALUE, which the modifier that shows it also animates through its `$`
// binding (`.opacity($fade)`, then `$fade.animateTo(0.1, length: 400)` - see
// Core/Flight.swift), or a CONTROL, whose address `.assign` puts into state.
// On a value you WRITE; on a control you CALL - and which member is which is
// not this library's taste but MAUI's decision, read off MAUI: a settable
// BindableProperty is a property here, a method is a method here. `Focus`,
// `ScrollToAsync`, `MoveToRegion` and `GoBack` are methods in MAUI (their
// state is behind read-only keys, or they mean "again", which no value can
// say on a wire where an absent field means unchanged), so they are acts here.
//
// THE MECHANISM is the differ's: every element carries an identity - allocated
// once, never reused, stable for as long as the element stays in the tree -
// and it is on the wire already, being what C# matches controls by.
// `.assign()` links the box to the node, the differ writes the settled
// identity into the box as it walks, and the act sends it: a NUMBER for an
// element the author never named, the NAME for one that also says `.id("x")` -
// the two namespaces the tree's ids have. The host resolves them through
// `StateUIRenderer.Tracked` and `Named`.
//
// WHY A BOX INSIDE THE CLASS. `Node.assigned` has to hold whatever was written
// on the view without knowing WHICH control it is about - a node is not
// generic - so the erased `ControlBox` is what the tree stores and the typed
// `ControlState<Target>` is what the author holds. The type parameter is
// therefore pure surface: it is what makes `goBack()` offer itself on a
// WebView's state and nowhere else.
//
// WHY THE BOX SURVIVES ANYTHING. `@State` adoption carries the same
// `ControlState` - and with it the same box - from render to render. Even
// without it the mechanism holds, because the differ REFILLS the box on every
// walk that visits the element and the identity is stable, so the write is
// idempotent, so even a plain `let` in the view would work. Declaring it as
// state is what makes the doctrine one sentence instead of two.
//
// WHAT IT DOES NOT DO: it takes no part in MATCHING. A view carrying only an
// assignment is identified by the builder's path or its position, exactly as
// if nothing were written on it. Identity stays `.id()`'s job - a string the
// author chose, found wherever it moved to, which is what a collection's rows
// need - and the two compose: `.id("row-7").assign(row)` is a named row an act
// can also reach.

import Dispatch

/// A control an act can reach, held in state.
///
/// `.assign()` links it to a view, and the differ fills it with the identity
/// it settled for that element. So the act aims at exactly the view this state
/// was assigned to: there is no name to spell, to misspell, or to use twice,
/// and two instances of one composed view each aim at their own.
///
///     @State private var browser = ControlState<WebView>()
///
///     WebView(address).assign(browser)
///     Button("Back").onClicked { try await browser.goBack() }
///
/// The type parameter names the CONTROL, so it offers exactly what that
/// control can do: `focus()`/`unfocus()` on any of them, and an act one kind
/// of control has on that kind alone - `scrollTo` on a
/// `ControlState<ScrollView>`, `goBack` on a `ControlState<WebView>`,
/// `moveToRegion` on a `ControlState<Map>`. `.assign()` takes a
/// `ControlState<Self>`, which keeps the declaration and the view agreeing at
/// compile time; the host still verifies at run time, because a view can leave
/// the tree after the act was written.
///
/// Declared as `@State`, which is what carries the same one across renders -
/// and what makes the rule one sentence: everything an author holds is state,
/// either a value the modifier showing it also animates, or a control an act
/// is about.
///
/// This is NOT an identity: a view carrying only an assignment is still
/// matched by where it was written, so a collection's rows keep wanting
/// `.id()` - and both compose, an assignment on a named element aiming with
/// the name.
///
/// One of these names ONE view. An act on a state that never reached
/// `.assign()` - or that was assigned to two views at once - throws, saying
/// which of the two it was; one whose view has LEFT the tree keeps its last
/// identity, and the act reports there is no such view on screen, which is
/// what acting on a vanished view answers.
public final class ControlState<Target>: Sendable, CustomStringConvertible {
    /// Where the identity lives - untyped, because the tree holds it too and a
    /// node knows nothing about which control it is for.
    let box = ControlBox()

    /// A fresh one, assigned to nothing until `.assign()` puts it on a view
    /// and that view renders.
    public init() {}

    /// What it is assigned to - "#17", or "unassigned" - so printing one says
    /// something useful.
    public var description: String { box.label }

    /// The argument that tells the host which view an act is about: the
    /// element's identity, in the namespace it has - a number, or the name the
    /// author also gave it with `.id()`.
    ///
    /// It goes in argument 0, which is where every act the library ships puts
    /// it. That is the whole of aiming, and it is PUBLIC so that an application
    /// can aim an act of its OWN at a control of its own:
    ///
    ///     extension Act {
    ///         static let spin = Act("Gallery.Spin")
    ///     }
    ///
    ///     extension ControlState where Target == ColorWheel {
    ///         public nonisolated(nonsending) func spin() async throws {
    ///             try await stateUICall(.spin, [try target])
    ///         }
    ///     }
    ///
    /// The C# half registers the performer with `StateUIActs.Add` and turns
    /// the identity back into the control with `StateUIActs.TargetOf` -
    /// `StateUIRenderer.Tracked` for a number, `Named` for a name. Both
    /// halves or neither: an aim this side sends alone is one no performer can
    /// resolve.
    ///
    /// Throws instead of guessing: a state that never reached `.assign()`, or
    /// one assigned to two views, has nothing sound to aim at, and an act that
    /// goes nowhere looks exactly like one that has not started yet.
    public var target: PropValue {
        get throws { try box.target }
    }
}

/// The box behind a `ControlState`: where the differ leaves the element's
/// identity, and where an act reads it back.
///
/// A class, and untyped, because the NODE holds one too - `Node.assigned` -
/// and a node is not generic. `@unchecked Sendable` with every read and write
/// behind one serial queue: the differ writes on the UI thread while an act
/// may read from a cooperative-pool thread (`async let` runs its child there),
/// the same crossing `Renderer.guarded` exists for. That queue is also what
/// lets `ControlState` itself be checked `Sendable` - its only storage is this
/// box, and it never changes.
final class ControlBox: @unchecked Sendable, Hashable {
    /// One lock for every box: assignments are a few per render and reads a
    /// few per act, so contention is not a thing this needs to be clever
    /// about.
    private static let guarded = DispatchQueue(label: "StateUI.ControlBox")

    /// The identity of the element this was last assigned to.
    private var identity: ElementId?

    /// Which walk last assigned it - what tells a second view in the SAME
    /// render (a conflict) from the next render assigning it afresh.
    private var walk = 0

    /// Whether the last walk found this box on two elements. Cleared by the
    /// first assignment of the next walk, so fixing the tree fixes the state.
    private var conflicted = false

    /// Called by the differ for every element whose node carries this box: the
    /// first assignment of a walk takes the identity, a second one in the same
    /// walk is a conflict the next act reports.
    func attach(_ id: ElementId, walk: Int) {
        Self.guarded.sync {
            if self.walk != walk {
                self.walk = walk
                identity = id
                conflicted = false
            } else if identity != id {
                conflicted = true
            }
        }
    }

    /// The act argument this box aims with, or why it cannot.
    var target: PropValue {
        get throws {
            let (identity, conflicted) = Self.guarded.sync { (self.identity, self.conflicted) }

            if conflicted {
                throw StateUIError(
                    message: "this control state is assigned to two views - one names "
                        + "ONE; give each view its own")
            }

            switch identity {
            case .auto(let number):
                return .number(Double(number))
            case .manual(let name):
                // TEXT, exactly as an element's own manual id crosses in
                // Core/Wire.swift: an identity is the string the author
                // wrote, not an entry in a vocabulary, so there is nothing
                // for the session dictionary to number it against.
                return .string(name)
            case nil:
                throw StateUIError(
                    message: "this control state is not assigned to any view - write "
                        + ".assign(...) on the view, and act after it has rendered")
            }
        }
    }

    /// What `ControlState.description` says.
    var label: String {
        let (identity, conflicted) = Self.guarded.sync { (self.identity, self.conflicted) }

        if conflicted { return "conflicted" }

        switch identity {
        case .auto(let number): return "#\(number)"
        case .manual(let name): return name
        case nil: return "unassigned"
        }
    }

    /// Two boxes are the same box: this is storage, the way a `@State` is.
    static func == (left: ControlBox, right: ControlBox) -> Bool {
        left === right
    }

    /// By identity, matching `==`.
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
