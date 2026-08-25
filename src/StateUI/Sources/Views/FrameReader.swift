// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Measuring what a layout decided.
//
//     VStack { … }
//         .onFrameChanged { frame in height = frame.height }
//
//     FrameReader { frame in
//         Label("drawn into \(Int(frame.width)) points")
//     }
//
// The MODIFIER is the mechanism: any view can report the frame layout gave
// it, and MAUI has no event for that, so it is the library's own - named
// FRAME because a frame is where a view sits in its PARENT's coordinates,
// where "bounds" would say the view's own.
//
// The CONTAINER is Swift-side sugar over it, and earns its place by what the
// modifier cannot do: its content is built FROM the measurement. A
// `FrameReader` holds the last frame in a `@State` of its own, so the closure
// runs again whenever the frame settles somewhere new, with the measurement
// arriving through the same channel as every other report. Nothing about it
// exists on the C# side at all.
//
// ONE REPORT CARRIES EVERY SPACE. The wire says
// "x,y,width,height,windowX,windowY,safeX,safeY" - the frame in the parent,
// then the same origin converted to the window, then measured from where
// content can safely sit - and the modifier picks the four values its space
// means. That is why there is no property saying which space was asked for:
// the host computes all of it in one walk, and nothing about the choice
// crosses the boundary.
//
// NOTHING IS MEASURED UNLESS SOMETHING ASKS. A view without a handler is not
// even subscribed - the rule `.width($w)` and `.height($h)` follow, because a
// frame moves at every measure and a standing subscription per control would
// cost real work for an answer nobody wanted.
//
// WHEN IT REPORTS: when the view's own frame settles or moves, when an
// ANCESTOR's does, when a scroll among the ancestors moves the view against
// the window, and when the view is attached. A view that asked about its
// frame is listening to the whole chain above it - attached on the first
// report and re-walked on every attach, let go when the view leaves the
// window - because scrolling changes the `.global` and `.safeArea` answers
// without the view's own frame moving an inch. Each report is deduplicated
// against the last, so a layout pass that writes four components is one
// report - and each HANDLER dedupes again in its own space, so a `.parent`
// listener hears nothing of a scroll that changed only the window origin.
// What never reports: translate, rotate and scale are TRANSFORMS, which MAUI
// keeps off `Frame` entirely, so an animated translation reports nothing
// while an animated `widthRequest` reports every step of the layout it
// causes.

/// Which coordinates a measurement is answered in.
public enum CoordinateSpace: Sendable {
    /// The frame as the parent placed it: `x` and `y` are offsets inside the
    /// parent, the way UIKit's `frame` reads. What a reader answers unless
    /// told otherwise.
    case parent

    /// The same rectangle with its origin converted to the WINDOW, ancestor
    /// offsets and scroll positions accounted for. What positioning something
    /// over the whole interface wants.
    case global

    /// Measured from where content can SAFELY sit - past the status bar, the
    /// notch AND whatever bar was drawn above the page, so a view at the
    /// very top of its page's content reads zero, on every platform. The
    /// origin is the page's own corner plus the insets the platform still
    /// charges it - a flyout header reaching behind the status bar is charged
    /// that bar, a page parked below the navigation bar is charged nothing.
    /// On Windows, and headlessly, this agrees with `.global`.
    case safeArea
}

extension View {
    /// Reports this view's own frame as layout settles it.
    ///
    ///     VStack {
    ///         …
    ///     }
    ///     .onFrameChanged { frame in height = frame.height }
    ///     .onFrameChanged(in: .global) { frame in anchor = frame }
    ///
    /// This library's own - MAUI has no event for the frame a layout gave a
    /// view. The first layout reports too, so the handler needs no special
    /// case for "nothing measured yet". Written more than once it reports each
    /// space to its own handler. The handler is a handler like any other: it
    /// may write `@State` and it may await.
    ///
    /// **A TRANSFORM never reports.** `.translationX`, `.rotation` and
    /// `.scale` change what is drawn without moving the frame - MAUI keeps
    /// them off `Frame` entirely - so an animated translation is silent here,
    /// while an animated `.widthRequest` reports every step of the layout it
    /// causes.
    ///
    /// - Parameters:
    ///   - space: Which coordinates to answer in - the parent's unless said.
    ///   - handler: What to run with each settled frame.
    public func onFrameChanged(
        in space: CoordinateSpace = .parent,
        _ handler: @escaping ValueEventHandler<Rect>
    ) -> Modified {
        // One report serves every space, so a report may carry no news for
        // THIS one: scrolling moves the window origin while the parent frame
        // stands still. Each handler remembers the last rectangle it handed
        // over and stays quiet while its own answer is unchanged - which is
        // what keeps a `.parent` listener out of a scroll entirely.
        let last = LastFrame()

        return addHandler(.frameChanged) {
            guard let report = FrameReport(EventBuffer.current.value()) else { return }

            let frame = report.frame(in: space)
            guard frame != last.rect else { return }

            last.rect = frame
            try await handler(frame)
        }
    }
}

/// What a frame handler last handed over - a reference, so the closure that
/// captures it can remember across reports.
///
/// Reset when the view is rebuilt, the closure being rebuilt with it; the one
/// cost is a single repeated callback after a rebuild, which the handler's
/// own state write absorbs (an equal value renders once and changes nothing).
private final class LastFrame: @unchecked Sendable {
    /// The rectangle the handler last ran with.
    var rect: Rect?
}

/// A container whose content is built FROM the space it was given.
///
///     FrameReader { frame in
///         Label("half of \(Int(frame.width)) is \(Int(frame.width / 2))")
///             .widthRequest(frame.width / 2)
///     }
///
/// Built on `.onFrameChanged`: the last measured frame lives in a `@State` on
/// this view, so the closure runs again whenever the frame settles somewhere
/// new - the first layout included, before which it is given a zero rectangle.
/// More than one view stacks the way a plain `Grid` stacks them, on top of
/// each other.
///
/// For REPORTING a frame rather than building from it, write
/// `.onFrameChanged` on the view that has one - this container is for content
/// that cannot be described until its space is known.
public struct FrameReader: ContentView {
    /// The last frame the layout settled on - zero until the first report.
    @State private var frame = Rect(0, 0, 0, 0)

    /// Which coordinates the closure is handed.
    private let space: CoordinateSpace

    /// What to show, given the space it will live in.
    private let build: (Rect) -> [Element]

    /// A reader handing its content closure the frame in its PARENT's
    /// coordinates, which is the measurement content is usually built from.
    ///
    /// - Parameter content: What to show, built again as each measurement
    ///   settles.
    public init(@ViewBuilder _ content: @escaping (Rect) -> [Element]) {
        self.init(in: .parent, content)
    }

    /// The same, in the coordinates named - `.global` for where this sits in
    /// the window, `.safeArea` for where it sits inside what is not covered.
    ///
    /// - Parameters:
    ///   - space: Which coordinates to hand over.
    ///   - content: What to show, built again as each measurement settles.
    public init(
        in space: CoordinateSpace,
        @ViewBuilder _ content: @escaping (Rect) -> [Element]
    ) {
        self.space = space
        self.build = content
    }

    /// The content, in a Grid that fills the offered space and hears its own
    /// frame - the measurement writes the `@State` above, and the write is
    /// what builds this body again.
    public var content: Element {
        Grid {
            build(frame)
        }
        .onFrameChanged(in: space) { frame = $0 }
    }
}

/// One measurement as the host sends it: every space in eight numbers.
struct FrameReport {
    /// The frame in the parent's coordinates.
    let frame: Rect

    /// The same rectangle with its origin in the window's.
    let global: Rect

    /// And measured from where content can safely sit.
    let safeArea: Rect

    /// Reads the eight numbers of one report - x, y, width, height, windowX,
    /// windowY, safeX, safeY, one `numbers` value. Anything else is nil, and
    /// the caller leaves the handler alone: a payload that will not read is
    /// a version mismatch, not an event.
    init?(_ value: PropValue?) {
        guard let numbers = value?.numbers, numbers.count == 8 else { return nil }
        frame = Rect(numbers[0], numbers[1], numbers[2], numbers[3])
        global = Rect(numbers[4], numbers[5], numbers[2], numbers[3])
        safeArea = Rect(numbers[6], numbers[7], numbers[2], numbers[3])
    }

    /// The rectangle a space means.
    func frame(in space: CoordinateSpace) -> Rect {
        switch space {
        case .parent: return frame
        case .global: return global
        case .safeArea: return safeArea
        }
    }
}
