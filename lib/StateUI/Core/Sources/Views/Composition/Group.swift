// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A view written in place of another, with no element and no layout of its own: what it holds stands where the
/// group stands. A modifier written on it is about whichever view it shows - an `.onChanged` watches across the
/// branches of the `if/else` it holds.
///
///     Group {
///         if signedIn {
///             Text("Signed in")
///         } else {
///             Button("Sign in").onClicked { signedIn = true }
///         }
///     }
///     .onChanged(signedIn) { changes += 1 }
///
/// It holds one view - an `if/else` is one - and is built with the view it is written in, as its content cannot be
/// compared.
public struct Group<Content: View>: View {
    private let content: Content

    /// A group of `content`.
    ///
    /// - Parameter content: the view it holds.
    public init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }

    /// What it holds.
    public var body: some View {
        content
    }
}
