// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a host's passing tests proved, as its run writes it beside the host's export: one member of one element a
/// line, "Label.text", sorted - the host's column's every ✅ and ☑️.
/// Design: docs/design/host/conformance.md#what-a-run-proves
public enum Coverage {
    /// The text of `covered`.
    public static func text(_ covered: Set<Covered>) -> String {
        covered.map(\.description).sorted().joined(separator: "\n") + "\n"
    }
}
