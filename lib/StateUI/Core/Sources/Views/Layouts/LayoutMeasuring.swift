// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What measures a layout's views for its arithmetic: the host's measure, asked once a view and a room in each
/// working-out.
/// Design: docs/design/core/layout-program.md#measuring-the-views
@MainActor
final class LayoutMeasuring {
    /// The host's measure of a view by its place; nil before a host said one.
    var measure: HostChildMeasure?

    private struct Asked: Hashable {
        let index: Int
        let proposal: LayoutProposal
    }

    private var answered: [Asked: HostChildMeasured] = [:]

    /// A new working-out: what was measured before is asked again.
    func begin() {
        answered.removeAll(keepingCapacity: true)
    }

    /// Forgets what was measured, as a view may measure otherwise; whether anything was.
    func forget() -> Bool {
        defer { answered.removeAll(keepingCapacity: true) }
        return !answered.isEmpty
    }

    /// The view at `index` in the room `proposal` offers: an answer that is no size is nought, said once.
    func measured(_ index: Int, _ proposal: LayoutProposal) -> HostChildMeasured {
        let asked = Asked(index: index, proposal: proposal)
        if let known = answered[asked] { return known }
        var size = measure?(index, proposal.width, proposal.height) ?? HostChildMeasured(size: .zero, firstBaseline: nil)
        if !size.size.width.isFinite || !size.size.height.isFinite || size.size.width < 0 || size.size.height < 0 {
            complain("A view measured for a layout answered a size that is none: it stands at nought.")
            size = HostChildMeasured(size: .zero, firstBaseline: nil)
        }
        answered[asked] = size
        return size
    }
}
