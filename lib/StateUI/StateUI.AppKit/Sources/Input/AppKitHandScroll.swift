// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// Scroll events - a trackpad's or a Magic Mouse's fingers, a wheel - offered to the hands of the views under the
/// pointer before AppKit dispatches them, so a view of any class hears a hand.
/// Design: docs/design/platforms/appkit/input.md#the-hand-over-a-layout
@MainActor
enum AppKitHandScroll {
    /// The readers of the views that hear a hand, by view, and those a gesture under way began over, innermost
    /// first: its steps and its momentum are theirs.
    private static let readers = NSMapTable<NSView, AppKitHandReader>.weakToWeakObjects()
    private static var gesture: [Weak] = []

    private static let monitor: Any? = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: monitored)

    /// A scroll event as the monitor is handed it, on the main thread: nil where a hand took it.
    nonisolated static func monitored(_ event: NSEvent) -> NSEvent? {
        nonisolated(unsafe) let heard = event
        return MainActor.assumeIsolated { offered(heard, over: under(heard)) } ? nil : event
    }

    /// `view` hears the hand through `reader`, or - nil - no longer.
    static func hear(_ reader: AppKitHandReader?, on view: NSView) {
        _ = monitor
        if let reader { readers.setObject(reader, forKey: view) } else { readers.removeObject(forKey: view) }
    }

    /// Whether `view` hears a hand.
    static func hears(_ view: NSView) -> Bool { readers.object(forKey: view) != nil }

    /// `event` offered to the hands from `view` up: a gesture's beginning to every one of them, its steps and its
    /// momentum to the innermost of those that takes them, and a wheel with no phase to the innermost that does.
    /// A scroller standing between the pointer and a hand keeps the event. Whether a hand took it.
    static func offered(_ event: NSEvent, over view: NSView?) -> Bool {
        let begins = event.phase.contains(.began) || event.phase.contains(.mayBegin)
        guard begins || (event.phase.isEmpty && event.momentumPhase.isEmpty) else {
            return gesture.contains { $0.reader?.scrolled(event) == true }
        }

        var chain: [AppKitHandReader] = []
        var each = view
        while let view = each, !(view is NSScrollView) {
            if let reader = readers.object(forKey: view) { chain.append(reader) }
            each = view.superview
        }
        guard begins else { return chain.contains { $0.scrolled(event) } }

        gesture = chain.map(Weak.init)
        // Every hand under the pointer hears the beginning: whose the gesture is, its first move says.
        return chain.reduce(false) { $1.scrolled(event) || $0 }
    }

    /// The view under the pointer of `event`, in its window.
    private static func under(_ event: NSEvent) -> NSView? {
        event.window?.contentView?.superview?.hitTest(event.locationInWindow)
    }

    private struct Weak {
        weak var reader: AppKitHandReader?
    }
}
#endif
