// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// The frame clock: the frames GTK draws a window in, through its tick callback, added while held.
/// Design: docs/design/platforms/gtk/runtime.md#one-frame
@MainActor
final class GTKFrameClock: FrameClock {
    /// The runtime's time, in milliseconds on GLib's monotonic clock.
    let now: () -> Double

    /// What a frame does, handed that frame's time.
    var onFrame: ((Double) -> Void)?

    /// Whether something holds the clock. Frames come only while it does.
    var held = false {
        didSet { if held != oldValue { follow() } }
    }

    /// The widget whose frames the clock ticks with: the window; nil before there is one.
    var widget: GTKWidget? {
        didSet { if widget != oldValue { follow() } }
    }

    /// Whether GTK's frames drive the clock; a test's hand-wound clock takes none.
    private let ticksWithGTK: Bool
    private var tick: guint = 0
    private var tickedWidget: GTKWidget?

    /// The one clock, which the tick callback reaches.
    static var current: GTKFrameClock?

    /// A clock telling `now`'s time: GLib's monotonic one, or a test's hand-wound one.
    init(now: @escaping () -> Double = GTKFrameClock.monotonic, ticksWithGTK: Bool = true) {
        self.now = now
        self.ticksWithGTK = ticksWithGTK
        Self.current = self
    }

    /// Takes the tick off the widget held, and lets go of it.
    isolated deinit {
        guard let tickedWidget else { return }
        if tick != 0 { gtk_widget_remove_tick_callback(tickedWidget, tick) }
        g_object_unref(tickedWidget)
    }

    /// A frame GTK draws: the frame's work at this moment; whether the clock is still held.
    func frame() -> Bool {
        guard held else { return false }
        onFrame?(now())
        return held
    }

    /// Adds the tick callback to the widget while held, and removes it otherwise. The widget ticked with is held
    /// until the clock moves on: a window closed can go before the clock follows another.
    private func follow() {
        let wanted = held && ticksWithGTK ? widget : nil
        guard wanted != tickedWidget || (wanted != nil && tick == 0) else { return }

        if let tickedWidget {
            if tick != 0 { gtk_widget_remove_tick_callback(tickedWidget, tick) }
            g_object_unref(tickedWidget)
        }
        tick = 0
        tickedWidget = wanted
        guard let wanted else { return }

        g_object_ref(wanted)
        tick = gtk_widget_add_tick_callback(wanted, { _, _, _ in
            MainActor.assumeIsolated {
                guard let clock = GTKFrameClock.current else { return 0 }
                if clock.frame() { return 1 }
                clock.tick = 0
                return 0
            }
        }, nil, nil)
    }

    /// Milliseconds on GLib's monotonic clock.
    nonisolated static func monotonic() -> Double {
        Double(g_get_monotonic_time()) / 1_000
    }
}
