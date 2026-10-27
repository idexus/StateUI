// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One group of the bar's actions standing together - a lone item's own too: the look the application gives the
/// group it stands for, and the pointer over it told to that group.
/// Design: docs/design/platforms/web/pages.md#a-bars-items-in-the-applications-look
@MainActor
final class WebBarGroup: WebDOMView {
    /// The group the view stands for.
    private(set) weak var group: MountedElement?

    init() {
        super.init(tag: "div")
        attribute("class", "stateui-bar-group")
        attribute("role", "group")
        for (said, event) in [("pointerenter", Event.pointerEntered), ("pointerleave", .pointerExited)] {
            listen(said) { [weak self] in (self?.group?.native as? WebElement)?.hearOnBar(event) }
        }
    }

    /// Stands for `group`, the group of the items it holds.
    func show(_ group: MountedElement?) {
        self.group = group
        showBarLook { group?.value($0) }
    }
}
