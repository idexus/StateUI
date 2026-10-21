// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a test asked of its window that the window could not do: find a view no view is, or one of two, or act on a
/// view in a way it takes no act.
public struct TestFailure: Error, CustomStringConvertible {
    /// What went wrong, naming the view.
    public let description: String
}
