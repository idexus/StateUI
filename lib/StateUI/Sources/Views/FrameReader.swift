// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Measuring what a layout decided: `.onFrameChanged` on any view, and
// `FrameReader`, a composed view whose content is built from its frame.
// Design: docs/design/views/measured-layouts.md#frame-reports

/// Which coordinates a measurement is answered in.
public enum CoordinateSpace: Sendable {
    /// The frame as the parent placed it: `x` and `y` are offsets inside the
    /// parent. The default.
    case parent

    /// The same rectangle with its origin converted to the window, ancestor
    /// offsets and scroll positions accounted for.
    case global

    /// Measured from where content can safely sit - past the status bar, the
    /// notch and any bar drawn above the page - so a view at the very top of
    /// its page's content reads zero on every platform. With no platform, in a
    /// test, it agrees with `.global`.
    case safeArea
}

extension View {
    /// Reports this view's own frame as layout settles it - the first layout
    /// included - and again when an ancestor's frame or a scroll moves it.
    ///
    ///     VStack {
    ///         …
    ///     }
    ///     .onFrameChanged { frame in height = frame.height }
    ///     .onFrameChanged(in: .global) { frame in anchor = frame }
    ///
    /// Each handler hears only changes in its own space. A transform -
    /// `.translationX`, `.rotation`, `.scale` - moves what is drawn and not the
    /// frame, so it reports nothing; an animated `.width` reports every step.
    ///
    /// - Parameters:
    ///   - space: Which coordinates to answer in - the parent's unless said.
    ///   - handler: What to run with each settled frame.
    public func onFrameChanged(
        in space: CoordinateSpace = .parent,
        _ handler: @escaping ValueEventHandler<Rect>
    ) -> Modified {
        // One report serves every space; each handler stays quiet while its
        // own answer is unchanged.
        let last = LastFrame()

        return onEvent(ViewContract.frameChanged) { numbers in
            guard let report = FrameReport(numbers) else { return }

            let frame = report.frame(in: space)
            guard frame != last.rect else { return }

            last.rect = frame
            try await handler(frame)
        }
    }
}

/// What a frame handler last handed over, remembered across reports; a
/// rebuilt view starts it afresh, costing one repeated report.
private final class LastFrame: @unchecked Sendable {
    /// The rectangle the handler last ran with.
    var rect: Rect?
}

/// A container whose content is built from the space it was given.
///
///     FrameReader { frame in
///         Label("half of \(Int(frame.width)) is \(Int(frame.width / 2))")
///             .width(frame.width / 2)
///     }
///
/// The closure runs again whenever the frame settles somewhere new; before the
/// first layout it is given a zero rectangle. Several views stack on top of
/// each other, as in a `Grid`. To report a frame rather than build from it,
/// write `.onFrameChanged` on the view.
public struct FrameReader: ContentView {
    /// The last frame the layout settled on - zero until the first report.
    @State private var frame = Rect(0, 0, 0, 0)

    /// Which coordinates the closure is handed.
    private let space: CoordinateSpace

    /// What to show, given the space it will live in.
    private let build: (Rect) -> [Element]

    /// A reader handing its content closure the frame in its parent's
    /// coordinates.
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

    /// The content, in a Grid that fills the offered space and writes its own
    /// frame into the state this body reads.
    public var content: any View {
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
    /// windowY, safeX, safeY; any other count is nil.
    init?(_ numbers: [Double]) {
        guard numbers.count == 8 else { return nil }
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
