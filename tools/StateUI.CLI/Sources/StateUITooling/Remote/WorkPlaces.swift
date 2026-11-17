// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Where a machine keeps other machines' work, `root`: `stateui-guest` under its user's home - each one's copies and
/// packages in its own folder, and in a guest of a Mac the guest's own stateui in `bin`.
/// Design: docs/design/tooling/guests.md#reaching-a-guest
struct WorkPlaces: Sendable, Equatable {
    let root: String
    let windows: Bool

    /// The places of a machine whose work folder is `root`, as its service says it (`workFolder`).
    init(root: String, windows: Bool) {
        (self.root, self.windows) = (root, windows)
    }

    /// The places of the user whose home is `home`.
    init(home: String, windows: Bool) {
        self.init(root: home + (windows ? "\\" : "/") + "stateui-guest", windows: windows)
    }

    /// The folder holding `root`: its user's home.
    var home: String {
        let separator: Character = windows ? "\\" : "/"
        return root.split(separator: separator, omittingEmptySubsequences: false).dropLast().joined(separator: String(separator))
    }

    /// The places of the work of the machine `client` names - its identity's short form: its own folder under `root`.
    func of(_ client: String) -> WorkPlaces {
        WorkPlaces(root: join(root, client), windows: windows)
    }

    /// A guest's own stateui, laid by the Mac.
    var tool: String { join(root, "bin", windows ? "stateui.exe" : "stateui") }

    func join(_ parts: String...) -> String {
        join(parts)
    }

    /// `parts` joined as the machine's system joins a path.
    func join(_ parts: [String]) -> String {
        parts.joined(separator: windows ? "\\" : "/")
    }

    /// `path`, a path of the machine, as a file URI its stateui reads.
    func uri(of path: String) -> String {
        let slashed = windows ? "/" + path.replacingOccurrences(of: "\\", with: "/") : path
        return "file://" + (slashed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slashed)
    }
}
