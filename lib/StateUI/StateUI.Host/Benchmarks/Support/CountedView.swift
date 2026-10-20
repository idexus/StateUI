// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A native half with no toolkit behind it, doing what every host's does with the host layer: it counts each call,
/// places a run's children in drawing order, keeps an ItemsView's cells, and says where it stands - in the bench's
/// room - where the tree reads it.
/// Design: docs/design/host/benchmarks.md#a-native-half-with-no-toolkit
@MainActor
final class CountedView: NativeElement, FrameReporter {
    let element: MountedElement
    private unowned let bench: Bench
    private(set) var cells: ItemsCells?

    let presentsView = true

    init(_ element: MountedElement, in bench: Bench) {
        self.element = element
        self.bench = bench
        bench.calls.made += 1
    }

    func standingValue(_ property: Prop) -> HostValue? { nil }

    func animates(_ property: Prop) -> Bool { false }

    func applied(changed: Set<Prop>, wasDescribed: Bool) {
        bench.calls.applied += 1
        if element.type == .itemsView {
            if cells == nil { cells = ItemsCells(element, in: bench.runtime) }
            if !wasDescribed || changed.contains(.items) { cells?.takeEntries() }
            cells?.childrenChanged()
        }
        if element.readsOwnFrame { bench.runtime.frames.follow(self, of: element, reads: true) }
        if !changed.isDisjoint(with: element.ownPlacementRun) { place() }
    }

    func presentFrame(_ changed: Set<Prop>) {
        bench.calls.presented += 1
        if !changed.isDisjoint(with: element.ownPlacementRun) { place() }
    }

    func arrangeChildren() {
        bench.calls.arranged += 1
        cells?.childrenChanged()
    }

    func directionChanged() {}

    func leave() {
        bench.calls.left += 1
    }

    func reportFrame() {
        element.reportFrame(
            MountedElement.frameNumbers(place: bench.room, corner: Point(0, 0), content: Point(0, 0)),
            in: bench.runtime)
    }

    /// The run's places, put as a host's layout puts them: in drawing order, each child at its place.
    private func place() {
        guard let placements = element.placement?.placements else { return }
        for index in ZStackArithmetic.drawingOrder(of: placements.count, placedBy: placements) {
            bench.placedAt = placements[index].place
            bench.calls.placed += 1
        }
    }
}
