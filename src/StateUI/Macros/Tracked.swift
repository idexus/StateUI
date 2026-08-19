// The two macros that act on a single property.
//
// `@Tracked` is where the observing actually happens, and it is the ordinary
// two-part trick: a PEER macro writes the storage the value really lives in,
// and an ACCESSOR macro turns the property the author declared into a computed
// one over it. So
//
//     var name = ""
//
// becomes a `_name` that holds the string and a `name` that reads it, writes it,
// and says the interface needs drawing again. Exactly what an author would
// otherwise write by hand, one line above and one line below.
//
// `@Untracked` writes nothing at all. It exists to be READ - by `@StateClass`,
// which looks for the name - and the empty accessor list is what keeps the
// property stored, since a macro that produces only observers (or nothing)
// leaves the storage where it was.

import SwiftSyntax
import SwiftSyntaxMacros

/// Gives one property the accessors that ask for another render.
public struct TrackedMacro {}

extension TrackedMacro: PeerMacro {
    /// Writes the stored property the value actually lives in.
    ///
    /// Always `private`, whatever the original said: nothing outside the class
    /// should be able to write the value without the interface hearing about
    /// it. `weak` and `unowned` DO travel, because they describe the storage
    /// rather than who may reach it.
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let property = declaration.as(VariableDeclSyntax.self),
              let stored = property.storedProperty else { return [] }

        let strength = property.referenceStrength
        let type = stored.binding.typeAnnotation.map { ": \($0.type.trimmedDescription)" } ?? ""
        let value = stored.binding.initializer.map { " = \($0.value.trimmedDescription)" } ?? ""

        return [
            "private \(raw: strength.isEmpty ? "" : strength + " ")var _\(stored.name)\(raw: type)\(raw: value)"
        ]
    }
}

extension TrackedMacro: AccessorMacro {
    /// Turns the property into a computed one over its storage.
    ///
    /// Three accessors, and the first is the one that is easy to leave out: an
    /// `init` accessor. Without it a class whose property has no default -
    /// `var name: String`, assigned in `init` - would be assigning through the
    /// SETTER before `self` is fully initialized, which Swift refuses. With it,
    /// that assignment initializes the storage directly, and no render is asked
    /// for while an object is still being built.
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let property = declaration.as(VariableDeclSyntax.self),
              let stored = property.storedProperty else { return [] }

        let storage = TokenSyntax.identifier("_\(stored.name.text)")

        return [
            """
            @storageRestrictions(initializes: \(storage))
            init(initialValue) {
                \(storage) = initialValue
            }
            """,
            // The read records a dependency while a view is being built - per
            // OBJECT, not per property, which is as fine as a name-free
            // mechanism can cut - and costs nearly nothing anywhere else.
            """
            get {
                StateUI.Renderer.shared.stateRead(self)
                return \(storage)
            }
            """,
            // Unconditionally, without comparing the old value: the values here
            // are whatever an author's model holds, and Equatable is not
            // something this can ask for. `@State` marks the tree dirty on
            // every write for the same reason, and the differ is what decides
            // that nothing actually changed. Naming `self` is what lets the
            // render that follows rebuild only the views that read this model.
            """
            set {
                \(storage) = newValue
                StateUI.Renderer.shared.stateChanged(self)
            }
            """,
        ]
    }
}

/// Keeps one property out of `@StateClass`'s reach.
public struct UntrackedMacro: AccessorMacro {
    /// Produces nothing, which is the whole point.
    ///
    /// It is declared as `@attached(accessor, names: named(willSet))` - naming
    /// an OBSERVER rather than a getter - so that returning no accessors at all
    /// leaves the property exactly as it was written. An accessor macro that
    /// promises a `get` and then produces none is an error; one that promises
    /// only `willSet` is allowed to change its mind.
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        []
    }
}
