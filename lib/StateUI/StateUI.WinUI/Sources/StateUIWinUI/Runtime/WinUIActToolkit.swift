// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// WinUI's part of the acts every host performs (`HostActPerformer`): the clock and the zones as ICU has them, a
/// question in WinUI's own dialog over the window the user is in, a word to Narrator, the focus, a value kept, a
/// list scrolled to an item, and the application's own acts.
/// Design: docs/design/host/runtime.md#acts
@MainActor
final class WinUIActToolkit: ActToolkit {
    private unowned let renderer: WinUIRenderer

    /// What hears each dialog's answer, by the ticket the dialog hands back.
    private let dialogs = Numbered<(Result<HostQuestion.Given, ActFailure>) -> Void>()

    /// The dialog showing: its ticket, the window it stands over, and the most characters its field takes.
    private var showing: Showing?

    private struct Showing {
        let ticket: Int64
        weak var window: WinUIWindow?
        let bound: Int?
    }

    init(renderer: WinUIRenderer) {
        self.renderer = renderer
    }

    let host = "WinUI"

    func localTime() -> (hour: Int, minute: Int, second: Int, millisecond: Int) {
        var time: [Int32] = [0, 0, 0, 0]
        stateui_winui_clock(&time)
        return (Int(time[0]), Int(time[1]), Int(time[2]), Int(time[3]))
    }

    func localZone() -> String {
        WinUIStrings.read { stateui_winui_time_zone($0, $1) }
    }

    func utcOffset(of zone: String?, on day: CalendarDate?) -> Int? {
        var minutes: Int32 = 0
        guard stateui_winui_utc_offset(
            zone, Int32(day?.year ?? 0), Int32(day?.month ?? 0), Int32(day?.day ?? 0), &minutes)
        else { return nil }
        return Int(minutes)
    }

    /// Asks in WinUI's own dialog over the window asked; its answer comes back by its ticket.
    /// Design: docs/design/platforms/winui/runtime.md#questions-for-the-user
    func show(
        _ question: HostQuestion, over window: MountedElement?,
        answered: @escaping (Result<HostQuestion.Given, ActFailure>) -> Void
    ) -> MountedElement? {
        guard let window = renderer.window(asked: window), let element = renderer.element(of: window), let content = window.content
        else { return nil }
        let ticket = dialogs.hold(answered)
        showing = Showing(ticket: ticket, window: window, bound: question.maximumLength)

        // The title, the message, the captions that accept and cancel, the placeholder, the first words.
        let kind: StateUIQuestionKind = switch question.kind {
        case .alert: .alert
        case .confirm: .confirm
        case .chooseAction: .chooseAction
        case .prompt: .prompt
        }
        let words: [String?] = [
            question.title, question.message, question.accept, question.cancel, question.placeholder, question.words,
        ]
        let traits = question.traits
        WinUIStrings.withCStrings(words.map { $0 ?? "" } + question.choices) { pointers in
            func at(_ index: Int) -> UnsafePointer<CChar>? { words[index] == nil ? nil : pointers[index] }
            Array(pointers.dropFirst(words.count)).withUnsafeBufferPointer { offered in
                var relayed = StateUIQuestion(
                    kind: kind, title: at(0), message: at(1), accept: at(2), cancel: at(3),
                    choices: offered.baseAddress, choiceCount: Int32(question.choices.count),
                    destructive: Int32(question.destructive ?? -1), placeholder: at(4),
                    maximumLength: Int32(question.maximumLength ?? 0), spellChecked: traits.checksSpelling,
                    predicted: traits.predicts, scope: WinUIInputScope(traits).rawValue, initial: at(5))
                stateui_winui_ask(content.handle, ticket, &relayed)
            }
        }
        return element
    }

    /// The words of the prompt asked under `ticket` changed: held within its bound in characters, whole while an input
    /// method is `composing` them (`InputWords.held`) - WinUI's own bound counts UTF-16 units.
    /// Design: docs/design/platforms/winui/runtime.md#questions-for-the-user
    func typed(ticket: Int64, _ words: String, composing: Bool) {
        guard let showing, showing.ticket == ticket, let content = showing.window?.content,
              let held = InputWords.held(words, in: nil, toBound: showing.bound, composing: composing)
        else { return }
        stateui_winui_prompt_write(content.handle, held)
    }

    /// The dialog under `ticket` was answered - accepted or not, and the words chosen or typed - or failed.
    func answered(ticket: Int64, _ answer: Result<HostQuestion.Given, ActFailure>) {
        if showing?.ticket == ticket { showing = nil }
        dialogs.take(ticket)?(answer)
    }

    /// `window` closed: the dialog standing over it - shown, or waiting for WinUI to load the window - goes with it,
    /// and its answer counts for nothing; the host layer answers its question (`HostActPerformer.windowsOpen`).
    /// Design: docs/design/platforms/winui/runtime.md#questions-for-the-user
    func windowWent(_ window: WinUIWindow) {
        guard let went = showing, went.window === window else { return }
        showing = nil
        _ = dialogs.take(went.ticket)
    }

    /// Shows every window in `theme`: each window's content in WinUI's own theme, the system's for `.system`.
    func useColorScheme(_ theme: ColorScheme) {
        for controller in renderer.windows { controller.window.useTheme(theme) }
    }

    func announce(_ words: String) {
        if let content = renderer.userWindow?.content { stateui_winui_announce(content.handle, words) }
    }

    func hideOnScreenKeyboard(in window: MountedElement?) -> Bool {
        renderer.window(asked: window)?.content.map { stateui_winui_hide_keyboard($0.handle) } ?? false
    }

    /// Design: docs/design/platforms/winui/runtime.md#acts
    func focus(_ element: MountedElement) -> Bool? {
        guard let view = (element.native as? WinUIElement)?.view else { return nil }
        // A view WinUI has not laid out yet stands in no window and refuses the focus: its window lays out first.
        if let content = renderer.controller(of: element)?.window.content { stateui_winui_update_layout(content.handle) }
        return stateui_winui_focus(view.handle, true)
    }

    func unfocus(_ element: MountedElement) -> Bool {
        guard let view = (element.native as? WinUIElement)?.view else { return false }
        _ = stateui_winui_focus(view.handle, false)
        return true
    }

    func keep(_ call: HostActCall) -> Bool {
        switch call.act {
        case .persistValue:
            WinUIPersistence.keep(call, core: renderer.runtime.core)
        case .persistSceneValue:
            let scenes = renderer.scenes
            if scenes.keep(call.arguments), let text = scenes.changed(root: renderer.runtime.tree.root) {
                WinUIPersistence.writeScenes(text)
            }
        default:
            return false
        }
        return true
    }

    /// An ItemsView's scroll to an item.
    func performOwn(_ call: HostActCall) -> Bool {
        guard call.act == .scrollTo else { return false }
        let core = renderer.runtime.core
        do {
            let element = try renderer.runtime.tree.aimed(call)
            guard let items = (element.native as? WinUIElement)?.view as? WinUIItemsView else {
                core.fail(call, "scrollTo is an act of an ItemsView", log: { WinUIRenderer.log.error($0) })
                return true
            }
            items.scroll(
                to: call.arguments.value(1)?.string ?? "",
                anchor: call.arguments.value(2).flatMap(ScrollAnchor.init(propValue:)) ?? .nearest)
            core.reply(call, [])
        } catch {
            core.fail(call, error.reason, log: { WinUIRenderer.log.error($0) })
        }
        return true
    }

    /// An act the application registered: its own, or one aimed at its own element.
    func performRegistered(_ call: HostActCall) -> Bool {
        WinUIInterop.acts.perform(
            call, in: renderer.runtime.tree, core: renderer.runtime.core, view: { ($0.native as? WinUIElement)?.view },
            log: { WinUIRenderer.log.error($0) })
    }

    func log(_ message: String) {
        WinUIRenderer.log.error(message)
    }
}
