// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An aim: which control an act is about - the element's key, declared on the view
// with `@Aim` and filled by the differ as it walks.
// Design: docs/design/core/acts.md#aims


/// Which control an act is aimed at, declared on the view beside its state.
///
///     @Aim(WebView.self) private var browser
///
///     WebView(address).aim(browser)
///     Button("Back").onClicked { try await browser.goBack() }
///
/// `.aim(_:)` puts it on a view, and the act reaches exactly that view: there is
/// no name to spell, and two instances of one composed view each aim at their
/// own. The declared type is the control, so the aim offers what that control
/// can do - `focus()` on any, `goBack` on a web view's. A view handed an aim keeps
/// it in a plain property and aims at its parent's control.
///
/// An aim is not a key: a collection's rows still want `.id()`, and the two
/// compose. An act on an aim that reached no view, or two, throws; one whose view
/// has left reports that no such view is on screen.
@propertyWrapper
public final class Aim<Target>: @unchecked Sendable, CustomStringConvertible {
    /// Where the key lives - untyped, because the tree holds it too. Replaced at most
    /// once, by adoption, before anything holding the view can act.
    private(set) var box = AimBox()

    /// An aim at a control of this kind, aimed at nothing until `.aim(_:)`
    /// puts it on a view and that view renders.
    ///
    ///     @Aim(TextField.self) private var field
    ///
    /// - Parameter target: the kind of control it aims at.
    public init(_ target: Target.Type) {}

    /// The aim itself - what the declared property answers, and what
    /// `.aim(_:)` and the acts are written against.
    public var wrappedValue: Aim<Target> { self }

    /// Where it is aimed - "#17", the name an `.id()` gave the view,
    /// "nowhere" or "two views" - so printing one says something useful.
    public var description: String { box.label }

    /// The argument that tells the host which view an act is about: the element's
    /// key, a number or the `.id()` name. Throws rather than guess where the aim is on
    /// no view or on two.
    var target: PropValue {
        get throws { try box.target }
    }

    /// Performs an act of the aimed element's contract on it - the element
    /// first, then the arguments the contract declares - and answers with the
    /// values it declares.
    ///
    ///     extension Aim where Target == TrafficLight {
    ///         func flash(times: Int) async throws {
    ///             try await call(TrafficLightContract.flash, times)
    ///         }
    ///     }
    ///
    /// An application aims an act of its own at a control of its own this way:
    /// the host half registers a performer under the act's name and turns the
    /// identity back into the control. Both halves or neither - an aim this
    /// side sends alone is one no performer can resolve.
    ///
    /// Throws where the aim is on no view or on two, where the host could not
    /// perform the act, and where the answer is not what the contract
    /// declares.
    ///
    /// - Parameters:
    ///   - act: the member, written with its contract.
    ///   - arguments: its arguments, in the order the contract declares them.
    /// - Returns: the answer, as the contract declares it.
    @discardableResult
    public nonisolated(nonsending) func call<
        Owner: Contract, each Argument: HostRepresentable, each Answer: HostRepresentable
    >(
        _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
        _ arguments: repeat each Argument
    ) async throws -> (repeat each Answer) {
        let aimed = try target
        let reply = try await Renderer.shared.call(
            act.token, [aimed] + MemberValues.encode(repeat each arguments))
        return try MemberValues.answer(reply, of: act.name, as: repeat (each Answer).self)
    }
}

extension Aim: StateBox {
    /// Takes over the box of the aim this one follows, so every aim a view was built
    /// with aims through one box.
    func adopt(from other: AnyObject) {
        if let other = other as? Aim<Target> {
            box = other.box
        }
    }

    /// The box, which is what says two aims are one.
    var lender: AnyObject { box }
}

/// Any aim - what the state walk asks to tell an aim a view was handed from one it
/// declares.
/// Design: docs/design/core/acts.md#an-aim-a-view-is-handed
protocol Aiming: AnyObject {
    /// The box it aims through.
    var box: AimBox { get }
}

extension Aim: Aiming {}

/// The box behind an `Aim`, where the differ leaves the element's key and an act
/// reads it; every read and write goes through one lock.
final class AimBox: @unchecked Sendable, Hashable {
    /// One lock for every box: a few attachments per render, a few reads per act.
    private static let guarded = Lock()

    /// The identity of the element this was last put on.
    private var identity: ElementId?

    /// Which walk last attached it, so a second view in one walk is a conflict.
    private var walk = 0

    /// Whether the last walk found it on two elements; the next walk's first
    /// attachment clears it.
    private var conflicted = false

    /// Attaches the element's key: the first attachment of a walk takes it, a second
    /// in the same walk is a conflict.
    func attach(_ id: ElementId, walk: Int) {
        Self.guarded.withLock {
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
            let (identity, conflicted) = Self.guarded.withLock { (self.identity, self.conflicted) }

            if conflicted {
                throw StateUIError(
                    message: "this aim is on two views - an aim names ONE; "
                        + "declare one for each view")
            }

            switch identity {
            case .auto(let number):
                return .number(Double(number))
            case .manual(let name):
                // The author's name, as text - as an element's own manual id crosses.
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
        let (identity, conflicted) = Self.guarded.withLock { (self.identity, self.conflicted) }

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
