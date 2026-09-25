// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// Performs the acts the application calls on the host, and answers each - a reply with its values, or a failure
/// with the reason - so a caller never waits on an act nobody performs.
/// Design: docs/design/platforms/winui/runtime.md#acts
@MainActor
final class WinUIActPerformer {
    private let core: CoreLink

    init(core: CoreLink) {
        self.core = core
    }

    /// Performs one act, and answers it; `window` is where a word to a screen reader and the keyboard stand.
    func perform(_ call: HostActCall, in tree: MountedTree, window: WinUIWindow?) {
        switch call.act {
        case .currentTime:
            var time: [Int32] = [0, 0, 0, 0]
            stateui_winui_clock(&time)
            reply(call, [time.map(Double.init).propValue])
        case .currentTimeZone:
            reply(call, [.string(WinUIStrings.read { stateui_winui_time_zone($0, $1) })])
        case .utcOffset:
            utcOffset(call)
        case .announce:
            if let content = window?.content { stateui_winui_announce(content.handle, call.arguments.first?.string ?? "") }
            reply(call, [])
        case .hideOnScreenKeyboard:
            reply(call, [.bool(window?.content.map { stateui_winui_hide_keyboard($0.handle) } ?? false)])
        case .focus, .unfocus:
            focus(call, in: tree)
        case .persistValue:
            WinUIPersistence.keep(call, core: core)
            reply(call, [])
        case .handlerFailed:
            WinUILog.error("a handler failed: \(call.arguments.first?.string ?? "")")
            reply(call, [])
        default:
            fail(call, "the WinUI host does not perform the act '\(call.act.name)'")
        }
    }

    /// How far a zone is from UTC on a day, in minutes, as ICU says; a zone it does not know fails the act.
    private func utcOffset(_ call: HostActCall) {
        let zone = call.arguments.value(0)?.string
        let day = call.arguments.value(1).flatMap { CalendarDate(propValue: $0) }
        var minutes: Int32 = 0
        guard stateui_winui_utc_offset(
            zone, Int32(day?.year ?? 0), Int32(day?.month ?? 0), Int32(day?.day ?? 0), &minutes)
        else { return fail(call, "no time zone '\(zone ?? "")' is known") }

        reply(call, [.number(Double(minutes))])
    }

    /// Puts the focus on the view the act names, or takes it off; `focus` answers whether the view took it.
    private func focus(_ call: HostActCall, in tree: MountedTree) {
        guard let view = aimed(call, in: tree) else { return }

        let done = stateui_winui_focus(view.handle, call.act == .focus)
        reply(call, call.act == .focus ? [.bool(done)] : [])
    }

    /// The view the act is aimed at, which its first argument names; nil, the act failed, where there is none.
    private func aimed(_ call: HostActCall, in tree: MountedTree) -> WinUIView? {
        let target: ElementId? = switch call.arguments.first {
        case .string(let name)?: .manual(name)
        case .number(let number)?: .auto(Int(number))
        default: nil
        }
        guard let target else {
            fail(call, "\(call.act.name) has to say which view it is for")
            return nil
        }
        guard let view = (tree.root?.first(id: target)?.native as? WinUIElement)?.view else {
            fail(call, "there is no view \(target) on screen")
            return nil
        }
        return view
    }

    private func reply(_ call: HostActCall, _ values: [HostValue]) {
        if let completion = call.completion { _ = core.reply(completion, with: values) }
    }

    /// Fails an act: a caller waiting on it throws the reason, and one nobody waits for is logged.
    private func fail(_ call: HostActCall, _ reason: String) {
        if let completion = call.completion {
            _ = core.fail(completion, reason: reason)
        } else {
            WinUILog.error(reason)
        }
    }
}
