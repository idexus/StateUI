// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Reading one member of a class, and deciding what `@StateClass` owes it.
//
// The whole macro rests on this question, so it is asked in one place and
// answered with three outcomes rather than a Bool. The third one - "this looks
// like state and cannot be given accessors" - is the reason it is not a Bool:
// a property that silently goes untracked is a view that silently stops
// updating, which is the failure mode this project refuses everywhere else
// (an unknown node type draws a red marker; it does not disappear).

import SwiftDiagnostics
import SwiftSyntax

/// What `@StateClass` should do with one member of the class.
enum Tracking {
    /// A stored `var`: give it accessors that ask for another render.
    case track

    /// Nothing to do, and nothing to say - a `let`, a computed property, a
    /// static, or one the author has already spoken for with `@Untracked`.
    case leave

    /// Something that reads as state and cannot be given accessors. The string
    /// says why, and goes into the diagnostic as written.
    case impossible(String)
}

extension VariableDeclSyntax {
    /// What `@StateClass` should do with this property.
    var tracking: Tracking {
        // Already spoken for: `@Untracked` is the opt-out, and `@Tracked`
        // written by hand is an author who has said it twice.
        if hasAttribute("Untracked") || hasAttribute("Tracked") { return .leave }

        // A `let` cannot be written after init, so there is nothing to report.
        if bindingSpecifier.tokenKind == .keyword(.let) { return .leave }

        for modifier in modifiers {
            switch modifier.name.tokenKind {
            // A type's own value is not this instance's state, and `@State`
            // holds instances.
            case .keyword(.static), .keyword(.class):
                return .leave

            // `lazy` is itself an accessor Swift synthesizes, and a property
            // may only have one set.
            case .keyword(.lazy):
                return .impossible("is lazy, and Swift has already given it accessors")

            default:
                break
            }
        }

        guard bindings.count == 1 else {
            return .impossible("declares more than one property in a single `var`")
        }

        guard let binding = bindings.first,
              binding.pattern.is(IdentifierPatternSyntax.self) else {
            return .impossible("does not name a single property")
        }

        switch binding.accessorBlock?.accessors {
        case nil:
            return .track

        // `var total: Int { a + b }` - computed, stores nothing, and follows
        // whatever it is computed FROM, which is tracked.
        case .getter:
            return .leave

        case .accessors(let accessors):
            for accessor in accessors {
                switch accessor.accessorSpecifier.tokenKind {
                case .keyword(.willSet), .keyword(.didSet):
                    return .impossible(
                        "has a willSet or didSet, which keeps it a stored property")
                default:
                    // get, set, _read, _modify: computed again.
                    return .leave
                }
            }

            return .track
        }
    }

    /// The single stored property this declares, when that is what it is.
    ///
    /// Accessors can only be added to one property named by an identifier, so
    /// everything else - a tuple pattern, two names in one `var` - is nothing
    /// this macro can rewrite.
    var storedProperty: (name: TokenSyntax, binding: PatternBindingSyntax)? {
        guard bindings.count == 1,
              let binding = bindings.first,
              let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier
        else { return nil }

        return (name: name.trimmed, binding: binding)
    }

    /// Whether one of this declaration's attributes is `name`.
    ///
    /// The last dotted component, so `@StateUI.Untracked` counts as much as
    /// `@Untracked` - an author who qualifies the attribute means the same
    /// thing by it.
    func hasAttribute(_ name: String) -> Bool {
        attributes.contains { attribute in
            guard case .attribute(let attribute) = attribute else { return false }

            let written = attribute.attributeName.trimmedDescription
            return written.split(separator: ".").last.map(String.init) == name
        }
    }

    /// How this property holds its reference, when that is not the default.
    ///
    /// `weak` and `unowned` describe the STORAGE, so they belong on the stored
    /// property the macro writes rather than on the computed one that replaces
    /// it. Access control does not travel: the storage is always private.
    var referenceStrength: String {
        modifiers
            .filter {
                $0.name.tokenKind == .keyword(.weak) || $0.name.tokenKind == .keyword(.unowned)
            }
            .map(\.trimmedDescription)
            .joined(separator: " ")
    }
}

/// Something the macro has to say about the code it was applied to.
///
/// One id for all of them: they are all "this cannot be observed", and a
/// message that names the property and the way out is worth more than a
/// catalogue of codes.
struct StateClassDiagnostic: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "StateUI", id: "StateClass")
    let severity = DiagnosticSeverity.error

    init(_ message: String) {
        self.message = message
    }
}
