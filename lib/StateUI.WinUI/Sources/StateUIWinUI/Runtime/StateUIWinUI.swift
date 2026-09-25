// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// Runs a StateUI application as native WinUI 3 controls in the application's own process.
///
/// An application's WinUI head names the application to the host and hands it
/// the thread:
///
///     import HelloWorldUI
///     import StateUIWinUI
///
///     stateui_app_register()
///     StateUIWinUI.run()
///
/// `.scripts/WinUI/run-app.ps1` builds the head and lays the Windows App SDK
/// beside it. A control this host does not present yet shows its name in red
/// where it belongs.
public enum StateUIWinUI {
    /// Starts WinUI on this thread and runs the application until its last window closes.
    ///
    /// - Returns: the process's exit code - 0, or the failure WinUI started with.
    @discardableResult
    public static func run() -> Int32 {
        var callbacks = WinUICallbacks.table
        return stateui_winui_run(&callbacks)
    }
}

/// What the relay calls on the UI thread, each forwarded to the host by the view's number.
/// Design: docs/design/platforms/winui/relay.md#the-callbacks
enum WinUICallbacks {
    static var table: StateUIWinUICallbacks {
        StateUIWinUICallbacks(
            launched: { WinUIRenderer.launch() },
            turn: { MainActor.assumeIsolated { WinUIRenderer.shared?.pump() } },
            frame: { MainActor.assumeIsolated { WinUIFrameClock.current?.frame() } },
            measure: { view, width, height, size in
                // The relay's own out-parameter, written on the thread that handed it over.
                nonisolated(unsafe) let size = size
                MainActor.assumeIsolated {
                    guard let layout = WinUIView.find(view) as? WinUILayoutView, let size else { return }
                    let measured = layout.measure(width: width, height: height)
                    size[0] = measured.width
                    size[1] = measured.height
                }
            },
            arrange: { view, width, height in
                MainActor.assumeIsolated { (WinUIView.find(view) as? WinUILayoutView)?.arrange(width: width, height: height) }
            },
            clicked: { view in
                MainActor.assumeIsolated { WinUIView.find(view)?.clicked() }
            },
            toggled: { view, on in
                MainActor.assumeIsolated { (WinUIView.find(view) as? WinUISwitchView)?.onToggled?(on) }
            },
            valueChanged: { view, value in
                MainActor.assumeIsolated { (WinUIView.find(view) as? WinUISliderView)?.onValueChanged?(value) }
            },
            textChanged: { view, utf8 in
                let text = utf8.map { String(cString: $0) } ?? ""
                MainActor.assumeIsolated { (WinUIView.find(view) as? WinUITextFieldView)?.typed(text) }
            },
            submitted: { view in
                MainActor.assumeIsolated { (WinUIView.find(view) as? WinUITextFieldView)?.onSubmitted?() }
            },
            scrolled: { view, x, y in
                MainActor.assumeIsolated { (WinUIView.find(view) as? WinUIScrollerView)?.onScrolled?(Point(x: x, y: y)) }
            },
            held: { view, holding in
                MainActor.assumeIsolated { (WinUIView.find(view) as? WinUIScrollerView)?.onHeld?(holding) }
            },
            chosen: { view, index in
                MainActor.assumeIsolated { WinUIView.find(view)?.chose(Int(index)) }
            },
            presented: { view, open in
                MainActor.assumeIsolated { WinUIView.find(view)?.presented(open) }
            },
            environmentChanged: {
                MainActor.assumeIsolated { WinUIRenderer.shared?.environmentChanged() }
            })
    }
}
