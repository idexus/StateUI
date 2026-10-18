// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// Android's part of the acts every host performs (`HostActPerformer`): the clock and the zones, a question in the
/// platform's own dialog, a word to TalkBack, the focus and the keyboard, a value kept, and a web view's own acts.
/// A dialog and a script answer later, under a ticket they hand back - a number of the host's one count
/// (`HostNumbers`).
/// Design: docs/design/platforms/android/runtime.md#acts
@MainActor
final class AndroidActToolkit: ActToolkit {
    private let core: CoreLink

    /// The activity standing now, which shows a dialog, and its root and tree: the process's acts outlive each.
    private var context: jobject { AndroidRenderer.context }
    private var root: jobject { AndroidRenderer.shared!.root.reference }
    private func tree() -> MountedTree { AndroidRenderer.shared!.runtime.tree }

    /// The dialogs showing, by ticket, each with what hears its answer.
    private let dialogs = Numbered<(Bool, String?) -> Void>()

    /// The scripts not answered yet, by ticket.
    private let scripts = Numbered<HostActCall>()

    /// The tickets of the scripts waiting for their answer, oldest first.
    var waitingScripts: [Int64] { scripts.numbers }

    init(core: CoreLink) {
        self.core = core
    }

    /// Lets go of the dialogs the activity before left unanswered: their questions are asked again.
    func forgetDialogs() {
        dialogs.removeAll()
    }

    let host = "Android Views"

    func localTime() -> (hour: Int, minute: Int, second: Int, millisecond: Int) {
        let clock = (Java.frame { Java.callStaticObject(JavaAPI.environment, JavaAPI.clock).map(Java.intsOf) } ?? [])
            .map(Int.init) + [0, 0, 0, 0]
        return (clock[0], clock[1], clock[2], clock[3])
    }

    func localZone() -> String {
        Java.frame { Java.text(Java.callStaticObject(JavaAPI.environment, JavaAPI.zone)) }
    }

    func utcOffset(of zone: String?, on day: CalendarDate?) -> Int? {
        let minutes = Java.frame {
            Java.callStaticInt(
                JavaAPI.environment, JavaAPI.utcOffset, .object(zone.flatMap(Java.string)),
                .int(Int32(day?.year ?? 0)), .int(Int32(day?.month ?? 0)), .int(Int32(day?.day ?? 0)))
        }
        return minutes == Int32.min ? nil : Int(minutes)
    }

    /// Puts a question to the user in the platform's own dialog; its answer comes back by its ticket.
    func show(_ question: HostQuestion, answered: @escaping (Bool, String?) -> Void) -> Bool {
        let ticket = dialogs.hold(answered)
        Java.frame {
            let context = context
            switch question.kind {
            case .alert:
                Java.callStatic(
                    JavaAPI.dialogs, JavaAPI.alert, .object(context), .long(ticket),
                    .object(Java.string(question.title ?? "")), .object(Java.string(question.message ?? "")),
                    .object(Java.string(question.accept)))
            case .confirm:
                Java.callStatic(
                    JavaAPI.dialogs, JavaAPI.confirm, .object(context), .long(ticket),
                    .object(Java.string(question.title ?? "")), .object(Java.string(question.message ?? "")),
                    .object(Java.string(question.accept)), .object(Java.string(question.cancel ?? "Cancel")))
            case .chooseAction:
                Java.callStatic(
                    JavaAPI.dialogs, JavaAPI.chooseAction, .object(context), .long(ticket),
                    .object(Java.string(question.title ?? "")), .object(question.cancel.flatMap(Java.string)),
                    .object(question.destruction.flatMap(Java.string)),
                    .object(Java.strings(question.choices)))
            case .prompt:
                Java.callStatic(
                    JavaAPI.dialogs, JavaAPI.prompt, .object(context), .long(ticket),
                    .object(Java.string(question.title ?? "")), .object(Java.string(question.message ?? "")),
                    .object(Java.string(question.accept)), .object(Java.string(question.cancel ?? "Cancel")),
                    .object(question.placeholder.flatMap(Java.string)),
                    .int(Int32(question.maximumLength ?? -1)),
                    .int(question.traits.inputType(password: false, multiLine: false)),
                    .object(Java.string(question.words)))
            }
        }
        return true
    }

    /// The act under `ticket` was answered: a dialog accepted or not, with the words chosen or typed; or a script's
    /// value as JSON, said as text (`ScriptAnswer`) - one not accepted fails, its page gone before it answered.
    func answered(ticket: Int64, accepted: Bool, words: String?) {
        if let call = scripts.take(ticket) {
            guard accepted else {
                return core.fail(call, "the page went before the script answered", log: { AndroidRenderer.log.error($0) })
            }
            return core.reply(call, [ScriptAnswer.text(json: words).propValue])
        }
        dialogs.take(ticket)?(accepted, words)
    }

    func announce(_ words: String) {
        Java.frame {
            Java.call(root, JavaAPI.announceForAccessibility, .object(Java.string(words)))
        }
    }

    /// Shows the application in `theme` as its own night mode, which the system keeps and every activity takes.
    func useColorScheme(_ theme: ColorScheme) {
        Java.callStatic(JavaAPI.environment, JavaAPI.useNightMode, .object(AndroidRenderer.context), .int(theme.rawValue))
    }

    func hideOnScreenKeyboard() -> Bool {
        Java.callStaticBool(JavaAPI.environment, JavaAPI.hideKeyboard, .object(root))
    }

    func focus(_ element: MountedElement) -> Bool? {
        guard let view = (element.native as? AndroidElement)?.view else { return nil }
        return Java.callStaticBool(JavaAPI.views, JavaAPI.focus, .object(view.reference), .bool(true))
    }

    func unfocus(_ element: MountedElement) -> Bool {
        guard let view = (element.native as? AndroidElement)?.view else { return false }
        _ = Java.callStaticBool(JavaAPI.views, JavaAPI.focus, .object(view.reference), .bool(false))
        return true
    }

    func keep(_ call: HostActCall) -> Bool {
        switch call.act {
        case .persistValue: AndroidPersistence.keep(call, core: core, context: context)
        case .persistSceneValue: AndroidRenderer.shared?.keepSceneValue(call)
        default: return false
        }
        return true
    }

    /// A web view's own acts - stepping back or forward, loading again, running a script, which answers by ticket -
    /// and an ItemsView's scroll to an item.
    func performOwn(_ call: HostActCall) -> Bool {
        guard [.goBack, .goForward, .reload, .evaluateJavaScript, .scrollTo].contains(call.act) else { return false }
        let element: MountedElement
        do {
            element = try tree().aimed(call)
        } catch {
            core.fail(call, error.reason, log: { AndroidRenderer.log.error($0) })
            return true
        }
        if call.act == .scrollTo {
            guard let items = (element.native as? AndroidElement)?.view as? AndroidItemsView else {
                core.fail(call, "scrollTo is an act of an ItemsView", log: { AndroidRenderer.log.error($0) })
                return true
            }
            items.scroll(
                to: call.arguments.value(1)?.string ?? "",
                anchor: call.arguments.value(2).flatMap(ScrollAnchor.init(propValue:)) ?? .nearest)
            core.reply(call, [])
            return true
        }
        guard let web = (element.native as? AndroidElement)?.view as? AndroidWebView else {
            core.fail(call, "\(call.act.name) is an act of a web view", log: { AndroidRenderer.log.error($0) })
            return true
        }
        switch call.act {
        case .goBack: web.goBack()
        case .goForward: web.goForward()
        case .reload: web.reload()
        default:
            web.evaluate(call.arguments.value(1)?.string ?? "", ticket: waitForScript(call))
            return true
        }
        core.reply(call, [])
        return true
    }

    /// Keeps a script's `call` waiting for its answer, under the ticket this answers.
    private func waitForScript(_ call: HostActCall) -> Int64 {
        scripts.hold(call)
    }

    func performRegistered(_ call: HostActCall) -> Bool {
        AndroidInterop.acts.perform(
            call, in: tree(), core: core, view: { ($0.native as? AndroidElement)?.view }, log: { AndroidRenderer.log.error($0) })
    }

    func log(_ message: String) {
        AndroidRenderer.log.error(message)
    }
}
