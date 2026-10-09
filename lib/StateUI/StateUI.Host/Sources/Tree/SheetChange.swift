// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What the sheets a window shows become to stand as its modal stack asks, the same on every host: those shown that
/// stand as asked from the bottom stay, the rest leave from the top, and each asked for after them comes over the one
/// before.
/// Design: docs/design/host/pages.md#sheets
@_spi(Host) @MainActor public struct SheetChange<Shown, Asked> {
    /// How many of the shown stay, from the bottom.
    public let kept: Int

    /// The shown that leave, the top first.
    public let leaving: [Shown]

    /// The asked for that come, the bottom first.
    public let coming: [Asked]

    /// What `shown` becomes to stand as `asked`, the last of each on top; `stands` says whether a sheet shown is the
    /// one asked for in its place.
    public init(from shown: [Shown], to asked: [Asked], stands: (Shown, Asked) -> Bool) {
        var kept = 0
        while kept < shown.count, kept < asked.count, stands(shown[kept], asked[kept]) { kept += 1 }
        self.kept = kept
        leaving = shown[kept...].reversed()
        coming = Array(asked[kept...])
    }
}
