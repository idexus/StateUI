// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Where the element stands, said to the tree that reads it.
/// Design: docs/design/platforms/gtk/layout.md#where-a-view-stands
extension GTKElement {
    /// Whether the tree reads where this element stands: a state its frame drives, or a handler for its changes.
    var readsFrame: Bool {
        view != nil && (element.driven[.frame] != nil || element.handler(.frameChanged) != nil)
    }

    /// Says where the element stands, where that changed: onto the state its frame drives, and to its handler.
    func reportFrame() {
        guard let host, let view, readsFrame else { return }

        let report = view.frameReport()
        guard report != lastFrameReport else { return }
        lastFrameReport = report

        if let binding = element.driven[.frame] {
            host.report(.lanes(Array(report.prefix(4))), through: binding)
        }
        if let handler = element.handler(.frameChanged) {
            host.dispatch(handler, payload: [.numbers(report)])
        }
    }
}
