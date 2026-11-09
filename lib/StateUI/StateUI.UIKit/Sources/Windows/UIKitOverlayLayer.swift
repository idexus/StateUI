// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit

/// What a sheet lays over itself: its overlays, each with the sheet's whole room within its safe area, over its
/// pages and under a sheet presented over it. A touch beside what they hold goes on to the sheet.
/// Design: docs/design/platforms/uikit/pages.md#a-sheets-overlays
@MainActor
final class UIKitOverlayLayer: UIView {
    /// The overlays laid, the first lowest.
    private(set) var overlays: [UIView] = []

    /// Stands the layer over `controller`'s view - its sheet - within its safe area.
    func stand(over controller: UIViewController) {
        let host = controller.view!
        if superview !== host {
            removeFromSuperview()
            translatesAutoresizingMaskIntoConstraints = false
            host.addSubview(self)
            let area = host.safeAreaLayoutGuide
            NSLayoutConstraint.activate([
                leadingAnchor.constraint(equalTo: area.leadingAnchor), trailingAnchor.constraint(equalTo: area.trailingAnchor),
                topAnchor.constraint(equalTo: area.topAnchor), bottomAnchor.constraint(equalTo: area.bottomAnchor),
            ])
        }
        host.bringSubviewToFront(self)
    }

    /// Lays `overlays`, the first lowest, in place of those before.
    func lay(_ overlays: [UIView]) {
        guard !overlays.elementsEqual(self.overlays, by: ===) else { return }
        for leaving in self.overlays where !overlays.contains(where: { $0 === leaving }) { leaving.removeFromSuperview() }
        self.overlays = overlays
        for overlay in overlays { addSubview(overlay) }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for overlay in overlays { overlay.frame = bounds }
    }

    /// A touch on the layer itself, beside every overlay, goes on to the sheet under it.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}
#endif
