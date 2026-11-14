// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A conformance family's verdict file as two runs compare it: by its verdicts, whatever revision each stood at.
/// Design: docs/design/tooling/repository.md#the-android-hosts-suite
enum Verdicts {
    /// The verdicts of the file `text`, the line naming its revision aside.
    static func alone(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).filter { !$0.hasPrefix("# revision ") }.joined(separator: "\n")
    }
}
