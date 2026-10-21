// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI
import StateUIFoundation

/// Runs a StateUI application as native WinUI 3 controls in the application's own process.
///
/// An application's WinUI head names the application to the host and hands it
/// the thread:
///
///     import HelloWorldUI
///     import StateUIWinUI
///
///     registerApplication()
///     StateUIWinUI.run()
///
/// `.scripts/WinUI/run-app.ps1` builds the head and lays the Windows App SDK
/// beside it. A control this host does not present yet shows its name in red
/// where it belongs.
public enum StateUIWinUI {
    /// Starts WinUI on this thread, runs the application until its last window closes, and ends the process with
    /// 0 - or with the failure WinUI started with.
    public static func run() -> Never {
        var callbacks = WinUICallbacks.table
        exit(stateui_winui_run(&callbacks))
    }
}

/// What the relay calls on the UI thread, each forwarded to the host by the view's number.
/// Design: docs/design/platforms/winui/relay.md#the-callbacks
enum WinUICallbacks {
    static var table: StateUIWinUICallbacks {
        StateUIWinUICallbacks(
            launched: { WinUIRenderer.launch() },
            turn: { MainActor.assumeIsolated { WinUIDoorbell.turn() } },
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
                MainActor.assumeIsolated {
                    (WinUIView.find(view) as? WinUILayoutView)?.arrange(width: width, height: height)
                    WinUIRenderer.shared?.runtime.frames.laidOut()
                }
            },
            clicked: { view in
                MainActor.assumeIsolated { WinUIView.find(view)?.clicked() }
            },
            toggled: { view, on in
                MainActor.assumeIsolated { (WinUIView.find(view) as? WinUIToggleView)?.onToggled?(on) }
            },
            valueChanged: { view, value in
                MainActor.assumeIsolated { (WinUIView.find(view) as? WinUIValueView)?.onValueChanged?(value) }
            },
            textChanged: { view, utf8, composing in
                let text = utf8.map { String(cString: $0) } ?? ""
                MainActor.assumeIsolated { (WinUIView.find(view) as? WinUITextInputView)?.typed(text, composing: composing) }
            },
            promptTyped: { ticket, utf8, composing in
                let words = utf8.map { String(cString: $0) } ?? ""
                MainActor.assumeIsolated { WinUIRenderer.shared?.promptTyped(ticket: ticket, words, composing: composing) }
            },
            submitted: { view in
                MainActor.assumeIsolated { (WinUIView.find(view) as? WinUITextInputView)?.onSubmitted?() }
            },
            scrolled: { view, x, y in
                MainActor.assumeIsolated {
                    (WinUIView.find(view) as? WinUIScrollerView)?.onScrolled?(Point(x: x, y: y))
                    WinUIRenderer.shared?.runtime.frames.laidOut()
                }
            },
            held: { view, holding in
                MainActor.assumeIsolated { WinUIView.find(view)?.held(holding) }
            },
            refreshPulled: { view in
                MainActor.assumeIsolated { (WinUIView.find(view) as? WinUIRefreshView)?.onPulled?() ?? false }
            },
            chosen: { view, index in
                MainActor.assumeIsolated { WinUIView.find(view)?.chose(Int(index)) }
            },
            presented: { view, open in
                MainActor.assumeIsolated { WinUIView.find(view)?.presented(open) }
            },
            environmentChanged: {
                MainActor.assumeIsolated { WinUIRenderer.shared?.environmentChanged() }
            },
            heard: { view, what, phase, x, y, scale in
                if what == .press {
                    guard let phase = StateUIPressPhase(rawValue: phase) else { return }
                    return MainActor.assumeIsolated { WinUIView.find(view)?.heardPress(phase, at: Point(x: x, y: y)) }
                }
                if what == .tap {
                    return MainActor.assumeIsolated {
                        WinUIView.find(view)?.heardTap(at: Point(x: x, y: y), time: .milliseconds(Int(phase)))
                    }
                }
                guard let heard = HeardInput(what, phase: phase, x: x, y: y, scale: scale) else { return }
                MainActor.assumeIsolated { WinUIView.find(view)?.heard(heard) }
            },
            answered: { ticket, accepted, utf8, chosen, failure in
                let words = utf8.map { String(cString: $0) }
                let given = chosen >= 0
                    ? HostQuestion.Given(chosen: Int(chosen)) : HostQuestion.Given(accepted: accepted, words: words)
                let answer: Result<HostQuestion.Given, ActFailure> = failure.map { .failure(ActFailure(String(cString: $0))) }
                    ?? .success(given)
                MainActor.assumeIsolated { WinUIRenderer.shared?.answered(ticket: ticket, answer) }
            },
            filesChosen: { ticket, count, paths, names, failure in
                let files = (0..<Int(count)).compactMap { index -> ChosenFile? in
                    guard let path = paths?[index], let name = names?[index] else { return nil }
                    return ChosenFile(address: String(cString: path), name: String(cString: name))
                }
                let why = failure.map { String(cString: $0) }
                MainActor.assumeIsolated { WinUIRenderer.shared?.fileToolkit.chose(ticket: ticket, files: files, failure: why) }
            },
            fileRead: { ticket, bytes, length, failure in
                let read = bytes.map { Array(UnsafeBufferPointer(start: $0, count: Int(length))) } ?? []
                let why = failure.map { String(cString: $0) }
                MainActor.assumeIsolated { WinUIRenderer.shared?.fileToolkit.read(ticket: ticket, bytes: read, failure: why) }
            },
            requestAnswered: { ticket, status, headers, body, length, failure in
                let said = headers.map { String(cString: $0) } ?? ""
                let read = body.map { Array(UnsafeBufferPointer(start: $0, count: Int(length))) } ?? []
                let why = failure.map { String(cString: $0) }
                MainActor.assumeIsolated {
                    WinUIRenderer.shared?.network.answered(
                        ticket: ticket, status: Int(status), headers: said, body: read, failure: why)
                }
            },
            launchAnswered: { ticket, taken in
                MainActor.assumeIsolated { WinUIRenderer.shared?.fileToolkit.launched(ticket: ticket, taken: taken) }
            },
            dragHeard: { view, heard, words in
                let said = words.map { String(cString: $0) } ?? ""
                MainActor.assumeIsolated { WinUIView.find(view)?.heardDrag(heard, words: said) }
            },
            filesDragged: { view, count, paths, names in
                let files = (0..<Int(count)).compactMap { index -> ChosenFile? in
                    guard let path = paths?[index], let name = names?[index] else { return nil }
                    return ChosenFile(address: String(cString: path), name: String(cString: name))
                }
                MainActor.assumeIsolated { WinUIView.find(view)?.heardDrag(.filesDropped(files)) }
            },
            canvasPressed: { view, phase, x, y in
                MainActor.assumeIsolated {
                    (WinUIView.find(view) as? WinUICanvasView)?.pressed(phase, at: Point(x: x, y: y))
                }
            },
            picked: { view, first, second, third in
                MainActor.assumeIsolated { WinUIView.find(view)?.picked(first, second, third) }
            },
            menuChosen: { view, index in
                MainActor.assumeIsolated { WinUIView.find(view)?.menuChosen(Int(index)) }
            },
            focused: { view, focused in
                MainActor.assumeIsolated { WinUIView.find(view)?.focusChanged(focused) }
            },
            windowStateChanged: { window, minimized, activated in
                MainActor.assumeIsolated {
                    WinUIRenderer.shared?.windowStateChanged(number: window, minimized: minimized, activated: activated)
                }
            },
            windowClosed: { window in
                MainActor.assumeIsolated { WinUIRenderer.shared?.windowClosed(number: window) }
            },
            windowLaidOut: { _ in
                MainActor.assumeIsolated { WinUIRenderer.shared?.runtime.frames.reportLaidOut() == true }
            },
            itemCell: { view, kind, cell in
                // The relay's own out-parameter, and the panel it takes a reference of.
                nonisolated(unsafe) let cell = cell
                nonisolated(unsafe) var panel: StateUIObjectRef?
                MainActor.assumeIsolated {
                    guard let made = WinUIItemsList.owner(of: view)?.makeCell(item: kind == .item) else { return }
                    cell?.pointee = made.number
                    panel = made.handle
                }
                return panel
            },
            itemHeld: { view, cell, utf8 in
                let identity = utf8.map { String(cString: $0) } ?? ""
                MainActor.assumeIsolated { WinUIItemsList.owner(of: view)?.held(identity, in: cell) }
            },
            itemLetGo: { view, cell in
                MainActor.assumeIsolated { WinUIItemsList.owner(of: view)?.letGo(cell) }
            },
            itemsChose: { view, utf8 in
                let joined = utf8.map { String(cString: $0) } ?? ""
                MainActor.assumeIsolated {
                    WinUIItemsList.owner(of: view)?.chose(joined.split(separator: "\n").map(String.init))
                }
            },
            itemInvoked: { view, utf8 in
                let identity = utf8.map { String(cString: $0) } ?? ""
                MainActor.assumeIsolated { WinUIItemsList.owner(of: view)?.invoked(identity) }
            },
            itemsShowing: { view, first, last in
                MainActor.assumeIsolated { WinUIItemsList.owner(of: view)?.showing(Int(first)...Int(last)) }
            },
            keyTaken: { view, key, modifiers in
                MainActor.assumeIsolated {
                    (WinUIView.find(view) as? WinUITitleBarView)?.takesKey(key: key, modifiers: modifiers) == true
                }
            },
            hand: { view, phase, x, y, time, speedX, speedY in
                MainActor.assumeIsolated {
                    let speed = speedX.isNaN || speedY.isNaN ? nil : Point(x: speedX, y: speedY)
                    return WinUIView.find(view)?.heardHand(phase: phase, moved: Point(x: x, y: y), at: time, speed: speed)
                        == true
                }
            },
            finger: { view, phase, pointer, x, y, inX, inY, time in
                MainActor.assumeIsolated {
                    WinUIView.find(view)?.heardFinger(
                        phase: phase, pointer: Int(pointer), at: Point(x: x, y: y), inView: Point(x: inX, y: inY),
                        time: time) ?? .left
                }
            },
            wheel: { view, x, y in
                MainActor.assumeIsolated { WinUIView.find(view)?.heardWheel(moved: Point(x: x, y: y)) == true }
            },
            mirrored: { view, phase, x, y, middleX, middleY in
                MainActor.assumeIsolated {
                    guard let phase = GesturePhase(rawValue: phase) else { return }
                    WinUIView.find(view)?.heard(.mirrored(phase, at: Point(x: x, y: y), middle: Point(x: middleX, y: middleY)))
                }
            })
    }
}
