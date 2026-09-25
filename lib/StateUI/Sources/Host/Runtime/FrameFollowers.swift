// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A scroller the display's frames serve while it moves or has something to say.
@_spi(Host) @MainActor public protocol FramedScroller: AnyObject {
    /// Whether it still wants the display's frames.
    var wantsFrames: Bool { get }

    /// Says what the frame at `now` saw it do.
    func frame(now: Double)
}

/// An element whose frame the tree reads.
@_spi(Host) @MainActor public protocol FrameReporter: AnyObject {
    /// Says where it stands, where that changed.
    func reportFrame()
}

/// What the display's frames serve besides the core's cycle: every scroller moving or with something to say, and
/// every element whose frame the tree reads - each in the order its view was made, as one user's transaction a
/// frame.
/// Design: docs/design/host/runtime.md#where-a-view-stands
@_spi(Host) @MainActor public final class FrameFollowers {
    private unowned let runtime: HostRuntime
    private var scrollers: [Int64: HeldScroller] = [:]
    private var reporters: [Int64: HeldReporter] = [:]
    private var moved = false

    private struct HeldScroller {
        weak var scroller: (any FramedScroller)?
    }

    private struct HeldReporter {
        weak var reporter: (any FrameReporter)?
    }

    init(runtime: HostRuntime) {
        self.runtime = runtime
    }

    /// Keeps the display's frames coming for `scroller`, made `order`th, until it stands and has said everything.
    public func serve(_ scroller: any FramedScroller, order: Int64) {
        scrollers[order] = HeldScroller(scroller: scroller)
        runtime.displayCycle.hold()
    }

    /// Follows where `reporter`, made `order`th, stands while `reads` - letting it go once the tree reads it no
    /// more.
    public func follow(_ reporter: any FrameReporter, order: Int64, reads: Bool) {
        guard reads != (reporters[order] != nil) else { return }
        reporters[order] = reads ? HeldReporter(reporter: reporter) : nil
        if reads { laidOut() }
    }

    /// Something was laid out or moved: whoever reads a frame says it on the display's next frame.
    public func laidOut() {
        guard !reporters.isEmpty, !moved else { return }
        moved = true
        runtime.displayCycle.hold()
    }

    /// Whether a scroller moves or has something to say, or a frame read may have moved.
    public var wantsFrames: Bool {
        moved || scrollers.values.contains { $0.scroller?.wantsFrames == true }
    }

    /// Lets every moving scroller say what the frame at `now` saw it do, then every reporter say where it stands,
    /// each in the order it was made, as one user's transaction.
    public func commit(now: Double) {
        guard !scrollers.isEmpty || moved else { return }
        runtime.performUserTransaction {
            for order in scrollers.keys.sorted() {
                guard let scroller = scrollers[order]?.scroller else {
                    scrollers[order] = nil
                    continue
                }
                scroller.frame(now: now)
                if !scroller.wantsFrames { scrollers[order] = nil }
            }

            guard moved else { return }
            moved = false
            for order in reporters.keys.sorted() {
                guard let reporter = reporters[order]?.reporter else {
                    reporters[order] = nil
                    continue
                }
                reporter.reportFrame()
            }
        }
    }
}
