// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIToolingProtocol

/// The StateUI release this tool belongs to.
public enum Release {
    /// The release, a copy of the library's `ApplicationInfo.libraryVersion`.
    public static let version = "0.8.5"

    /// StateUI's own repository, which releases are read and cloned from.
    public static let repository = "https://github.com/idexus/StateUI.git"

    /// The oldest release the tool can make an application from: its checkout has the library's heads and
    /// HelloWorld.
    public static let oldestUsable = "0.5.0"

    /// The tooling API versions this tool speaks.
    public static let apiVersions = [APIVersionRange(major: 1, minMinor: 0, maxMinor: 0)]

    /// The newest API version this tool speaks, which its one-shot answers are written in.
    public static var newestAPIVersion: String { apiVersions[apiVersions.count - 1].newest }
}
