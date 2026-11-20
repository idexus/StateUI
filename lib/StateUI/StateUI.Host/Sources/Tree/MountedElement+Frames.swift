// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What reads one of an element's two rectangles: the state the frame drives, and the handler of its changes.
struct FrameReader: Equatable {
    let state: HostStateBinding?
    let handler: Int32?

    /// The reader of `state` and `handler`; nil where there is neither.
    init?(state: HostStateBinding?, handler: Int32?) {
        guard state != nil || handler != nil else { return nil }
        self.state = state
        self.handler = handler
    }
}

/// What reads where an element stands, a stage each.
struct FrameReaders: Equatable {
    let layout: FrameReader?
    let presentation: FrameReader?
}

/// Where an element stands, said to the tree that reads it, the same on every host.
/// Design: docs/design/host/runtime.md#where-a-view-stands
extension MountedElement {
    /// Whether the tree reads where this element itself stands: a state its frame drives, a handler of its changes,
    /// a layout's program or a hand's unit worked out of its room, or - a split view - the state its sidebar's
    /// place drives (`reportSidebarOverlays(_:in:)`), said with it once laid out.
    public var readsOwnFrame: Bool {
        frameReaders != nil || driven[.sidebarOverlays] != nil || layoutProgram != nil || movesByItsLength
            || holdsDismissing || interactionProgram?.drag?.dismissal != nil
    }

    /// Whether the hand moves a value by the element's own length: the unit is read off where it stands.
    private var movesByItsLength: Bool {
        interactionProgram?.values.contains { value in
            if case .translation(_, .containerLength, _) = value.input { return true }
            return false
        } == true
    }

    /// What reads this element's frame itself, a stage each - a state it drives, a handler of its changes - or nil
    /// for nothing.
    var frameReaders: FrameReaders? {
        let layout = FrameReader(state: driven[.layoutFrame], handler: events[.layoutFrameChanged])
        let presentation = FrameReader(
            state: driven[.presentationFrame], handler: events[.presentationFrameChanged])
        return layout == nil && presentation == nil ? nil : FrameReaders(layout: layout, presentation: presentation)
    }

    /// Says where the element stands, as its host read it off the toolkit - `numbers`, a frame report's eight, the
    /// view where it is now with no transform in them: to the layout stage's readers where its layout puts it, to
    /// the presentation stage's the rectangle around what is drawn; each where that changed since it last said, or
    /// a reader came since.
    /// Design: docs/design/host/runtime.md#two-rectangles
    public func reportFrame(_ numbers: [Double], in runtime: HostRuntime) {
        guard lifecycle == .active else { return }
        // A layout's program works its children's places out of the room: it is told every room laid out.
        // Design: docs/design/host/layout.md#a-layout-program
        if numbers.count >= 4 {
            laidOutCorner = Point(x: numbers[0], y: numbers[1])
            laidOutRoom = (numbers[2], numbers[3])
            layoutProgram?.layOut(numbers[2], numbers[3])
        }
        guard let readers = frameReaders else { return }

        let due = frameReportDue
        frameReportDue = false
        if let reader = readers.layout {
            let (frame, carried) = layoutFrame(from: numbers)
            if due || Self.isAnother(frame, than: reportedFrame, cornerWorkedOut: carried || saidACornerWorkedOut) {
                reportedFrame = frame
                saidACornerWorkedOut = carried
                say(frame, to: reader, in: runtime)
            }
        }
        if let reader = readers.presentation {
            let frame = presentationFrame(from: numbers)
            if due || frame != reportedPresentation {
                reportedPresentation = frame
                say(frame, to: reader, in: runtime)
            }
        }
    }

    /// Whether the layout stage's report is another than the one last said. A place - the first four numbers -
    /// is another where any number of it is: the last step of a size coming to rest is said, however short. A
    /// corner worked out while a place travels carries its arithmetic's last digits, which are no move: one
    /// worked out, now or as it was said, is another only further than a millionth of a point.
    static func isAnother(_ frame: [Double], than said: [Double], cornerWorkedOut: Bool) -> Bool {
        guard said.count == frame.count, frame.count >= 4 else { return true }
        if frame.prefix(4) != said.prefix(4) { return true }
        guard cornerWorkedOut else { return frame != said }
        return zip(frame.dropFirst(4), said.dropFirst(4)).contains { abs($0 - $1) > 1e-6 }
    }

    private func say(_ numbers: [Double], to reader: FrameReader, in runtime: HostRuntime) {
        if let binding = reader.state {
            runtime.report(.lanes(Array(numbers.prefix(4))), through: binding, origin: .measurement)
        }
        if let handler = reader.handler {
            runtime.dispatch(handler, payload: [.numbers(numbers)])
        }
    }

    /// Where the element's place stands now and where its layout puts it, while the two differ: a child its
    /// layout's motion carries, or one a layout program's body brings onto its place.
    var travel: (standing: Rect, destination: Rect)? {
        tree?.layoutMotion.travel(of: mount) ?? parent?.programTravel(of: self)
    }

    /// The layout stage's report from the host's: the element where its layout puts it - at its destination where
    /// its place travels - and its corners where they stand once it and every layout above it have come to theirs;
    /// and whether a way, its own or a layout's above it, carried those corners.
    func layoutFrame(from numbers: [Double]) -> (frame: [Double], carried: Bool) {
        guard numbers.count >= 8 else { return (numbers, false) }

        var frame = numbers
        var (across, down) = (0.0, 0.0)
        if let own = travel {
            // What is left of its own way, from where the toolkit holds it now - the numbers its corner was read with.
            across += own.destination.x - numbers[0]
            down += own.destination.y - numbers[1]
            frame.replaceSubrange(
                0..<4, with: [own.destination.x, own.destination.y, own.destination.width, own.destination.height])
        }
        var above = parent
        while let layout = above {
            if let carried = layout.travel {
                across += carried.destination.x - carried.standing.x
                down += carried.destination.y - carried.standing.y
            }
            above = layout.parent
        }
        guard across != 0 || down != 0 else { return (frame, false) }
        frame[4] += across
        frame[5] += down
        frame[6] += across
        frame[7] += down
        return (frame, true)
    }

    /// The presentation stage's report from the host's: the rectangle around the element as it is drawn where it
    /// stands now, under its own transform - its move, its turn and its scales about its pivot.
    func presentationFrame(from numbers: [Double]) -> [Double] {
        guard numbers.count >= 8 else { return numbers }

        let place = Rect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
        let drawn = drawingTransform.bounds(of: place)
        guard drawn != place else { return numbers }
        let (across, down) = (drawn.x - place.x, drawn.y - place.y)
        return [
            drawn.x, drawn.y, drawn.width, drawn.height, numbers[4] + across, numbers[5] + down,
            numbers[6] + across, numbers[7] + down,
        ]
    }

    /// Whether a view may say where it stands: once a layout placed it - StateUI's (`placed`), or its toolkit's
    /// giving it a size - and never before, as a view meets a display frame before the pass that places it.
    public static func isLaidOut(placed: Bool, width: Double, height: Double) -> Bool {
        placed || width > 0 || height > 0
    }

    /// A frame report's eight numbers for a view standing at `place` in its parent, its top left corner at
    /// `corner` in its window, and the window's content - clear of its chrome - beginning at `content`: the place,
    /// the corner in the window, and the corner from the content's.
    public static func frameNumbers(place: Rect, corner: Point, content: Point) -> [Double] {
        [place.x, place.y, place.width, place.height, corner.x, corner.y, corner.x - content.x, corner.y - content.y]
    }

    /// Where the top left corner of the element's laid-out rectangle stands in its window, no transform in it: the
    /// toolkit's own (`toolkit`) where none stands on the element or a layout above it, else the corner of the
    /// layout placing it, with its `place` there added and that layout's `scrolled` offset taken away.
    /// Design: docs/design/host/runtime.md#a-corner-in-the-window
    public func cornerInWindow(
        toolkit: (MountedElement) -> Point?, place: (MountedElement) -> Point?, scrolled: (MountedElement) -> Point
    ) -> Point? {
        guard standsTransformed, let parent = layoutParent, let at = place(self),
              let above = parent.cornerInWindow(toolkit: toolkit, place: place, scrolled: scrolled)
        else { return toolkit(self) }
        let scroll = scrolled(parent)
        return Point(x: above.x + at.x - scroll.x, y: above.y + at.y - scroll.y)
    }

    /// Whether a transform - a move, a turn, a size - stands on the element or on a layout above it.
    var standsTransformed: Bool {
        var each: MountedElement? = self
        while let element = each {
            if Self.transforms.contains(where: { (element.number($0.property) ?? $0.none) != $0.none }) { return true }
            each = element.layoutParent
        }
        return false
    }

    /// The properties transforming what a view draws, each with the value that leaves it as it stands.
    private static let transforms: [(property: Prop, none: Double)] = [
        (.translationX, 0), (.translationY, 0), (.rotation, 0), (.rotationX, 0), (.rotationY, 0),
        (.scale, 1), (.scaleX, 1), (.scaleY, 1),
    ]
}
