// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Whether an element's words stand beside its picture (`TextAndIconElement`), alike on every host: always where it
/// has no picture; else as it says, and unsaid as its kind shows them - a button's words do, a bar's item's do not.
/// Words left out still name it to assistive technology.
/// Design: docs/design/host/pages.md#words-beside-a-picture
@_spi(Host) public enum TextAndIcon {
    /// Whether the words show, `said` what the element says, `hasPicture` whether it shows a picture, and
    /// `byDefault` what its kind shows unsaid.
    public static func showsText(_ said: Bool?, hasPicture: Bool, byDefault: Bool) -> Bool {
        !hasPicture || (said ?? byDefault)
    }
}
