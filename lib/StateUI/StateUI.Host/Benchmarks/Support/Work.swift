// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The work a gesture cost: the core's renders, the bodies they built, the views they walked and the identities
/// they named with a text; and the calls the host layer made on the native halves - each one a toolkit's call, or a
/// relay's on the Web and Android.
/// Design: docs/design/host/benchmarks.md#what-is-counted
struct Work: Equatable, CustomStringConvertible {
    var renders = 0
    var built = 0
    var walks = 0
    var texts = 0
    var made = 0
    var applied = 0
    var arranged = 0
    var presented = 0
    var placed = 0
    var left = 0

    /// The work done between `before` and this.
    static func - (done: Work, before: Work) -> Work {
        Work(
            renders: done.renders - before.renders, built: done.built - before.built,
            walks: done.walks - before.walks, texts: done.texts - before.texts, made: done.made - before.made,
            applied: done.applied - before.applied, arranged: done.arranged - before.arranged,
            presented: done.presented - before.presented, placed: done.placed - before.placed,
            left: done.left - before.left)
    }

    var description: String {
        "renders \(renders), built \(built), walks \(walks), texts \(texts), made \(made), applied \(applied), "
            + "arranged \(arranged), presented \(presented), placed \(placed), left \(left)"
    }
}
