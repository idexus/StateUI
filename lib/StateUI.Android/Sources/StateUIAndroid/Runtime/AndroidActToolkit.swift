// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Android's part of the acts every host performs (`HostActPerformer`): the clock and the zones, a question in the
/// platform's own dialog, a word to TalkBack, the focus and the keyboard, a value kept, and a web view's own acts.
/// A dialog and a script answer later, under a ticket they hand back: a dialog's counts up from one, a script's
/// down from minus one.
/// Design: docs/design/platforms/android/runtime.md#acts
@MainActor
final class AndroidActToolkit: ActToolkit {
    private let core: CoreLink
    private let context: JavaObject
    private let root: JavaObject
    private let tree: () -> MountedTree

    /// The dialogs showing, by ticket, each with what hears its answer.
    private var dialogs: [Int64: (Bool, String?) -> Void] = [:]
    private static var nextDialogTicket: Int64 = 1

    /// The scripts not answered yet, by ticket.
    private var scripts: [Int64: HostActCall] = [:]

    /// The next script's ticket: one number across every renderer of the process, below zero so it is never a
    /// dialog's.
    private(set) static var nextScriptTicket: Int64 = -1

    init(core: CoreLink, context: JavaObject, root: JavaObject, tree: @escaping () -> MountedTree) {
        self.core = core
        self.context = context
        self.root = root
        self.tree = tree
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
        let ticket = Self.nextDialogTicket
        Self.nextDialogTicket += 1
        dialogs[ticket] = answered
        Java.frame {
            let context = context.reference
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
                    .object(Java.array(of: JavaAPI.string, question.choices.map(Java.string))))
            case .prompt:
                Java.callStatic(
                    JavaAPI.dialogs, JavaAPI.prompt, .object(context), .long(ticket),
                    .object(Java.string(question.title ?? "")), .object(Java.string(question.message ?? "")),
                    .object(Java.string(question.accept)), .object(Java.string(question.cancel ?? "Cancel")),
                    .object(question.placeholder.flatMap(Java.string)),
                    .int(Int32(question.maximumLength ?? -1)), .int(Self.inputType(question.purpose)),
                    .object(Java.string(question.words)))
            }
        }
        return true
    }

    /// The act under `ticket` was answered: a dialog accepted or not, with the words chosen or typed; or a script's
    /// value as text.
    func answered(ticket: Int64, accepted: Bool, words: String?) {
        if let call = scripts.removeValue(forKey: ticket) { return core.reply(call, [words.propValue]) }
        dialogs.removeValue(forKey: ticket)?(accepted, words)
    }

    /// Android's input type for what a typed answer is for.
    private static func inputType(_ purpose: InputPurpose) -> Int32 {
        // InputType's text, number and phone classes, and the variations and flags each purpose asks for.
        switch purpose {
        case .numeric: 0x2
        case .telephone: 0x3
        case .email: 0x21
        case .url: 0x11
        case .plain: 0x8_0001
        case .chat, .text: 0xC001
        case .default: 0x1
        }
    }

    func announce(_ words: String) {
        Java.frame {
            Java.call(root.reference, JavaAPI.announceForAccessibility, .object(Java.string(words)))
        }
    }

    func hideOnScreenKeyboard() -> Bool {
        Java.callStaticBool(JavaAPI.environment, JavaAPI.hideKeyboard, .object(root.reference))
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
        guard call.act == .persistValue else { return false }
        AndroidPersistence.keep(call, core: core, context: context.reference)
        return true
    }

    /// A web view's own acts: stepping back or forward, loading again, running a script - which answers by ticket.
    func performOwn(_ call: HostActCall) -> Bool {
        guard [.goBack, .goForward, .reload, .evaluateJavaScript].contains(call.act) else { return false }
        let element: MountedElement
        do {
            element = try tree().aimed(call)
        } catch {
            core.fail(call, error.reason, log: { AndroidLog.error($0) })
            return true
        }
        guard let web = (element.native as? AndroidElement)?.view as? AndroidWebView else {
            core.fail(call, "\(call.act.name) is an act of a web view", log: { AndroidLog.error($0) })
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
        let ticket = Self.nextScriptTicket
        Self.nextScriptTicket -= 1
        scripts[ticket] = call
        return ticket
    }

    func performRegistered(_ call: HostActCall) -> Bool {
        AndroidInterop.acts.perform(
            call, in: tree(), core: core, view: { ($0.native as? AndroidElement)?.view }, log: { AndroidLog.error($0) })
    }

    func log(_ message: String) {
        AndroidLog.error(message)
    }
}
