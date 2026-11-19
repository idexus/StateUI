// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser

/// The library named on a command line: a checkout or a release.
struct LibraryOptions: ParsableArguments {
    @Option(help: "A StateUI checkout to build with.")
    var checkout: String?

    @Option(help: "A StateUI release to build with, cloned into the workspace's StateUI/.")
    var release: String?

    @Option(help: "The repository a release is cloned from; StateUI's own when left out.")
    var repository: String?

    func validate() throws {
        guard (checkout == nil) != (release == nil) else {
            throw ValidationError("Name one library: --checkout or --release.")
        }
    }
}
