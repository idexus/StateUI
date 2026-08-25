// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The compiler plugin behind `@StateClass`.
//
// A macro is not a library the application links against - it is an EXECUTABLE
// the compiler starts, hands a declaration to, and reads source back from. So
// nothing here ever runs in an app, on any platform: this whole directory is a
// build-time tool for the host, which is why it sits beside Sources/ rather
// than inside it, and why the scan the library's own tests do never reaches it.
//
// It is also the one place this repository depends on something it did not
// write. swift-syntax is what a macro is written against; there is no smaller
// way to read a Swift declaration than the parser Swift itself uses, and a
// regex over source code - fine in a test, which can only under-report - would
// here be a transformation applied to somebody's class.

import SwiftCompilerPlugin
import SwiftSyntaxMacros

/// The three macros the library declares, handed to the compiler by name.
///
/// The names here must match the `type:` in each `#externalMacro` over in
/// Sources/Core/StateClass.swift, and the module name - StateUIMacros - is
/// what `-load-plugin-executable <path>#StateUIMacros` names in the build
/// scripts.
@main
struct StateUIPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StateClassMacro.self,
        TrackedMacro.self,
        UntrackedMacro.self,
    ]
}
