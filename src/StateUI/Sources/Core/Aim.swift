// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// WHERE AN ACT IS AIMED: which control it is about, declared on the view.
//
// The tree describes what the interface IS; an act - putting the keyboard on a
// field, stepping back through a WebView's history, moving a map - has to say
// WHICH control it is about, and a description rebuilt every render has no
// object to point at. What survives a render is the element's IDENTITY, and an
// `Aim` is that identity, declared where the view declares its state:
//
//     @Aim(WebView.self) private var browser
//
//     WebView(address).aim(browser)
//     Button("Back").onClicked { try await browser.goBack() }
//
// AIMING IS WHAT THE HOST CALLS IT TOO: `StateUIRenderer.Aim` points an aiming
// map's entry at a view and `StateUISession.Aimed` resolves the control an act
// names, so one word covers the mechanism on both sides of the wire. It holds
// no state of the control's own - not a property, not a report, nothing
// readable - which is why it is not a `@State`: it is the answer to "which
// one", and nothing else.
//
// WHAT AN AUTHOR HOLDS IS DECLARED, ONE WAY FOR EACH KIND: a VALUE with
// `@State` - shown by the closures that read it, or walked by the host
// (`.opacity($fade)`, see Core/StateValue.swift) - and a CONTROL with `@Aim`,
// which `.aim(_:)` puts on a view. On a value you WRITE; on a control you
// CALL - and which member is which is not this library's taste but MAUI's
// decision, read off MAUI: a settable BindableProperty is a property here, a
// method is a method here. `Focus`, `MoveToRegion` and `GoBack` are methods in
// MAUI (their state is behind read-only keys, or they mean "again", which no
// value can say on a wire where an absent field means unchanged), so they are
// acts here. A scroller's offset is the one MAUI method answered with STATE
// instead - `scroll($:)`, both ways - because this side has an engine of its
// own to move it with, and a value that is where the scroller IS says more
// than a call that sends it.
//
// THE MECHANISM is the differ's: every element carries an identity - allocated
// once, never reused, stable for as long as the element stays in the tree -
// and it is on the wire already, being what C# matches controls by. `.aim(_:)`
// links the aim's box to the node, the differ writes the settled identity into
// the box as it walks, and the act sends it: a NUMBER for an element the
// author never named, the NAME for one that also says `.id("x")` - the two
// namespaces the tree's ids have. The host resolves them through
// `StateUIRenderer.Tracked` and `Named`.
//
// WHY A BOX INSIDE THE AIM. `Node.aim` has to hold whatever was written on the
// view without knowing WHICH control it is about - a node is not generic - so
// the erased `AimBox` is what the tree stores and the typed `Aim<Target>` is
// what the author holds. The type parameter is therefore pure surface: it is
// what makes `goBack()` offer itself on a WebView's aim and nowhere else, and
// `moveToRegion` on a map's.
//
// WHY THE BOX SURVIVES A RENDER. A view is a value built again on every
// render, and the `@Aim` on it with it - so a fresh aim ADOPTS its
// predecessor's box, paired by the path the walk reached it by, exactly as a
// fresh `@State` adopts its predecessor's storage (Core/Stateful.swift). Every
// aim a view was ever built with then aims through one box: a handler captured
// three renders ago aims where one captured now does, and a view the aim is
// handed to compares it by that box and is carried like a view handed any
// unchanged value. The differ REFILLS the box on every walk that visits the
// element, and the identity is stable, so the write is idempotent.
//
// AN AIM A VIEW IS HANDED IS NOT ITS OWN. `@Aim` declares one; a plain stored
// property holding one - a child given its parent's - BORROWS it: compared by
// the box it aims through, and never adopted, or a child handed another aim
// in the same place would take over the one its parent holds. The mirror tells
// the two apart by name, a wrapper's backing property being the declared one
// with a leading underscore. An aim in a MODEL is the model's, and the walk
// never enters a model - the view's `@State` keeps the model, and the model
// keeps the aim.
//
// WHAT IT DOES NOT DO: it takes no part in MATCHING. A view carrying only an
// aim is identified by the builder's path or its position, exactly as if
// nothing were written on it. Identity stays `.id()`'s job - a string the
// author chose, found wherever it moved to, which is what a collection's rows
// need - and the two compose: `.id("row-7").aim(row)` is a named row an act
// can also reach.

import Dispatch

/// Which control an act is aimed at, declared on the view beside its state.
///
///     @Aim(WebView.self) private var browser
///
///     WebView(address).aim(browser)
///     Button("Back").onClicked { try await browser.goBack() }
///
/// `.aim(_:)` puts it on a view, and the differ fills it with the identity it
/// settled for that element - so the act reaches exactly that view: there is
/// no name to spell, to misspell, or to use twice, and two instances of one
/// composed view each aim at their own.
///
/// The type named in the declaration is the CONTROL, so the aim offers exactly
/// what that control can do: `focus()`/`unfocus()` on any of them, and an act
/// one kind of control has on that kind alone - `goBack` on an `Aim<WebView>`,
/// `moveToRegion` on an `Aim<Map>`. `.aim(_:)` takes the view's own
/// `Aim<Self>`, which keeps the declaration and the view agreeing at compile
/// time; the host still verifies at run time, because a view can leave the
/// tree after the act was written.
///
/// Declared with `@Aim` - on a view, a window or a model alike - which keeps
/// it across renders the way `@State` keeps a value. A view HANDED one, a
/// child given its parent's, keeps it in a plain property
/// (`let field: Aim<Entry>`) and aims at its parent's control. It is not a
/// state: it holds nothing of the control's own, which is why it has a
/// declaration of its own.
///
/// This is NOT an identity: a view carrying only an aim is still matched by
/// where it was written, so a collection's rows keep wanting `.id()` - and
/// both compose, an aim on a named element aiming with the name.
///
/// One of these names ONE view. An act on an aim that never reached a view -
/// or that was put on two at once - throws, saying which of the two it was;
/// one whose view has LEFT the tree keeps its last identity, and the act
/// reports there is no such view on screen, which is what acting on a
/// vanished view answers.
@propertyWrapper
public final class Aim<Target>: @unchecked Sendable, CustomStringConvertible {
    /// Where the identity lives - untyped, because the tree holds it too and a
    /// node knows nothing about which control it is for.
    ///
    /// Replaced at most once, by adoption, on the thread that builds the view
    /// declaring the aim and before anything holding that view can act -
    /// which is what the `@unchecked` above rests on. What is INSIDE the box
    /// goes through the box's own lock.
    private(set) var box = AimBox()

    /// An aim at a control of this kind, aimed at nothing until `.aim(_:)`
    /// puts it on a view and that view renders.
    ///
    ///     @Aim(Entry.self) private var field
    ///
    /// - Parameter target: the kind of control it aims at.
    public init(_ target: Target.Type) {}

    /// The aim itself - what the declared property answers, and what
    /// `.aim(_:)` and the acts are written against.
    public var wrappedValue: Aim<Target> { self }

    /// Where it is aimed - "#17", the name an `.id()` gave the view,
    /// "nowhere" or "two views" - so printing one says something useful.
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
    ///     extension Aim where Target == ColorWheel {
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
    /// Throws instead of guessing: an aim that never reached a view, or one
    /// put on two, has nothing sound to aim at, and an act that goes nowhere
    /// looks exactly like one that has not started yet.
    public var target: PropValue {
        get throws { try box.target }
    }
}

extension Aim: StateBox {
    /// Takes over the box of the aim this one follows - the same declaration,
    /// one build earlier - so every aim a view was built with aims through
    /// one box. See Core/Stateful.swift.
    func adopt(from other: AnyObject) {
        if let other = other as? Aim<Target> {
            box = other.box
        }
    }

    /// The box, which is what says two aims are one.
    var lender: AnyObject { box }
}

/// Any aim, whatever it aims at - what the walk that finds a view's state asks
/// to tell an aim the view was HANDED from one it declares. See
/// Core/Stateful.swift.
protocol Aiming: AnyObject {
    /// The box it aims through.
    var box: AimBox { get }
}

extension Aim: Aiming {}

/// The box behind an `Aim`: where the differ leaves the element's identity,
/// and where an act reads it back.
///
/// A class, and untyped, because the NODE holds one too - `Node.aim` - and a
/// node is not generic. `@unchecked Sendable` with every read and write behind
/// one serial queue: the differ writes on the UI thread while an act may read
/// from a cooperative-pool thread (`async let` runs its child there), the same
/// crossing `Renderer.guarded` exists for.
final class AimBox: @unchecked Sendable, Hashable {
    /// One lock for every box: attachments are a few per render and reads a
    /// few per act, so contention is not a thing this needs to be clever
    /// about.
    private static let guarded = DispatchQueue(label: "StateUI.AimBox")

    /// The identity of the element this was last put on.
    private var identity: ElementId?

    /// Which walk last attached it - what tells a second view in the SAME
    /// render (a conflict) from the next render attaching it afresh.
    private var walk = 0

    /// Whether the last walk found this box on two elements. Cleared by the
    /// first attachment of the next walk, so fixing the tree fixes the aim.
    private var conflicted = false

    /// Called by the differ for every element whose node carries this box: the
    /// first attachment of a walk takes the identity, a second one in the same
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
                    message: "this aim is on two views - an aim names ONE; "
                        + "declare one for each view")
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
                    message: "this aim is on no view - write .aim(...) on the "
                        + "view, and act after it has rendered")
            }
        }
    }

    /// What `Aim.description` says.
    var label: String {
        let (identity, conflicted) = Self.guarded.sync { (self.identity, self.conflicted) }

        if conflicted { return "two views" }

        switch identity {
        case .auto(let number): return "#\(number)"
        case .manual(let name): return name
        case nil: return "nowhere"
        }
    }

    /// Two boxes are the same box: this is storage, the way a `@State` is.
    static func == (left: AimBox, right: AimBox) -> Bool {
        left === right
    }

    /// By identity, matching `==`.
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
