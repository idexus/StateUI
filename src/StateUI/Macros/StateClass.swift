// `@StateClass` on a class.
//
// It does two things and neither of them is the interesting part: it writes
// `@Tracked` above every stored `var` - see Tracked.swift, which is where the
// accessors come from - and it declares the conformance that says the class has
// been through here.
//
// Applying an attribute to each member rather than rewriting the class whole is
// what keeps the expansion readable: an author who asks to see it gets their own
// properties back with one attribute added, not a class they did not write.

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Makes every stored `var` on a class ask for another render when it is
/// written.
public struct StateClassMacro {}

extension StateClassMacro: MemberAttributeMacro {
    /// Answers, for one member at a time, whether it should be tracked.
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // A struct is diagnosed once, in the extension expansion below. Saying
        // it again per member would bury it.
        guard declaration.is(ClassDeclSyntax.self) else { return [] }
        guard let property = member.as(VariableDeclSyntax.self) else { return [] }

        switch property.tracking {
        case .track:
            return ["@Tracked"]

        case .leave:
            return []

        case .impossible(let reason):
            let name = property.bindings.first?.pattern.trimmedDescription ?? "This property"

            context.diagnose(Diagnostic(
                node: Syntax(property),
                message: StateClassDiagnostic("""
                    `\(name)` \(reason), so writing it cannot ask for a render. \
                    Mark it `@Untracked` if the interface does not need to know when \
                    it changes, or make it a plain stored `var` and do the extra work \
                    somewhere the interface can see.
                    """)))

            return []
        }
    }
}

extension StateClassMacro: ExtensionMacro {
    /// Adds `: StateClass`, which is how the rest of the library - and a test -
    /// can tell that a class has been through this macro.
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(ClassDeclSyntax.self) else {
            context.diagnose(Diagnostic(
                node: Syntax(node),
                message: StateClassDiagnostic("""
                    `@StateClass` describes a CLASS. A struct is a value: put it in \
                    `@State` and writing it already asks for a render, because the \
                    write goes through the box.
                    """)))

            return []
        }

        // Empty when the class already says it conforms, which is the compiler
        // asking not to be told twice.
        guard !protocols.isEmpty else { return [] }

        return [
            try ExtensionDeclSyntax("extension \(type.trimmed): StateUI.StateClass {}")
        ]
    }
}
