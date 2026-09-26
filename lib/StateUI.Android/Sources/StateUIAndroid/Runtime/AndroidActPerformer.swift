// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// Performs the acts the application calls on the host, and answers each - a reply with its values, or a
/// failure with the reason - so a caller never waits on an act nobody performs. A question for the user
/// answers when the user does, and a script when the page has run it: its call waits under a ticket the
/// dialog or the web view hands back.
/// Design: docs/design/platforms/android/runtime.md#acts
@MainActor
final class AndroidActPerformer {
    private let core: CoreLink
    private let context: JavaObject
    private let root: JavaObject

    /// What the dialogs ask, one showing at a time; each answers under its ticket.
    private let questions = QuestionQueue<Asked>()

    /// A question the application asked, and the ticket its answer comes back under.
    private final class Asked {
        let call: HostActCall
        let question: HostQuestion
        var ticket: Int64 = 0

        init(call: HostActCall, question: HostQuestion) {
            self.call = call
            self.question = question
        }
    }

    /// The scripts not answered yet, by ticket.
    private var scripts: [Int64: HostActCall] = [:]

    /// The next script's ticket: one number across every renderer of the process, below zero so it is never a
    /// question's, whose tickets count up from one.
    private(set) static var nextScriptTicket: Int64 = -1

    init(core: CoreLink, context: JavaObject, root: JavaObject) {
        self.core = core
        self.context = context
        self.root = root
    }

    /// Performs one act, and answers it.
    func perform(_ call: HostActCall, in tree: MountedTree) {
        switch call.act {
        case .currentTime:
            let clock = (Java.frame { Java.callStaticObject(JavaAPI.environment, JavaAPI.clock).map(Java.intsOf) } ?? [])
                .map(Int.init) + [0, 0, 0, 0]
            reply(call, HostActs.currentTime(hour: clock[0], minute: clock[1], second: clock[2], millisecond: clock[3]))
        case .currentTimeZone:
            let zone = Java.frame { Java.text(Java.callStaticObject(JavaAPI.environment, JavaAPI.zone)) }
            reply(call, [.string(zone)])
        case .utcOffset:
            utcOffset(call)
        case .alert, .confirm, .chooseAction, .prompt:
            guard let question = HostQuestion(call) else { return }
            let asked = Asked(call: call, question: question)
            let (ticket, showsNow) = questions.ask(asked)
            asked.ticket = ticket
            if showsNow { show(asked) }
        case .announce:
            Java.frame {
                Java.call(root.reference, JavaAPI.announceForAccessibility, .object(Java.string(call.arguments.first?.string ?? "")))
            }
            reply(call, [])
        case .hideOnScreenKeyboard:
            reply(call, [.bool(Java.callStaticBool(JavaAPI.environment, JavaAPI.hideKeyboard, .object(root.reference)))])
        case .focus, .unfocus:
            focus(call, in: tree)
        case .goBack, .goForward, .reload, .evaluateJavaScript:
            browse(call, in: tree)
        case .persistValue:
            AndroidPersistence.keep(call, core: core, context: context.reference)
            reply(call, [])
        case .handlerFailed:
            AndroidLog.error("a handler failed: \(call.arguments.first?.string ?? "")")
            reply(call, [])
        default:
            // An act the application registered (`InteropActs`).
            guard !AndroidInterop.acts.perform(
                call, in: tree, core: core, view: { ($0.native as? AndroidElement)?.view },
                log: { AndroidLog.error($0) })
            else { return }
            fail(call, "the Android Views host does not perform the act '\(call.act.name)'")
        }
    }

    /// The act under `ticket` was answered: a dialog accepted or not, and the words chosen or typed - the next
    /// question showing then - or a script's value as text.
    func answered(ticket: Int64, accepted: Bool, words: String?) {
        if let call = scripts.removeValue(forKey: ticket) { return reply(call, [words.propValue]) }
        guard let (asked, next) = questions.answered(ticket) else { return }

        reply(asked.call, asked.question.answer(accepted: accepted, words: words))
        if let next { show(next) }
    }

    /// Puts a question to the user in the platform's own dialog; its answer comes back by its ticket.
    /// Design: docs/design/platforms/android/runtime.md#acts
    private func show(_ asked: Asked) {
        let question = asked.question
        let ticket = asked.ticket
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

    /// How far a zone is from UTC on a day, in minutes, as the platform says; a zone it does not know fails the act.
    private func utcOffset(_ call: HostActCall) {
        let (zone, day) = HostActs.utcOffsetQuestion(call)
        let minutes = Java.frame {
            Java.callStaticInt(
                JavaAPI.environment, JavaAPI.utcOffset, .object(zone.flatMap(Java.string)),
                .int(Int32(day?.year ?? 0)), .int(Int32(day?.month ?? 0)), .int(Int32(day?.day ?? 0)))
        }
        guard minutes != Int32.min else { return fail(call, HostActs.unknownZone(zone).reason) }

        reply(call, HostActs.utcOffset(minutes: Int(minutes)))
    }

    /// Puts the focus on the view the act names, or takes it off; `focus` answers whether the view took it.
    private func focus(_ call: HostActCall, in tree: MountedTree) {
        guard let view = aimed(call, in: tree) else { return }

        let took = Java.callStaticBool(JavaAPI.views, JavaAPI.focus, .object(view.reference), .bool(call.act == .focus))
        reply(call, call.act == .focus ? [.bool(took)] : [])
    }

    /// Steps a web view back or forward, or loads it again; or runs a script in it, which answers by ticket.
    private func browse(_ call: HostActCall, in tree: MountedTree) {
        guard let view = aimed(call, in: tree) else { return }
        guard let web = view as? AndroidWebView else { return fail(call, "\(call.act.name) is an act of a web view") }

        switch call.act {
        case .goBack: web.goBack()
        case .goForward: web.goForward()
        case .reload: web.reload()
        default: return web.evaluate(call.arguments.value(1)?.string ?? "", ticket: waitForScript(call))
        }
        reply(call, [])
    }

    /// The view the act is aimed at, which its first argument names (`MountedTree.aimed`); nil, the act failed,
    /// where there is none.
    private func aimed(_ call: HostActCall, in tree: MountedTree) -> AndroidView? {
        do {
            let element = try tree.aimed(call)
            guard let view = (element.native as? AndroidElement)?.view else {
                fail(call, "\(element.id) has no view")
                return nil
            }
            return view
        } catch {
            fail(call, error.reason)
            return nil
        }
    }

    /// Keeps a script's `call` waiting for its answer, under the ticket this answers.
    private func waitForScript(_ call: HostActCall) -> Int64 {
        let ticket = Self.nextScriptTicket
        Self.nextScriptTicket -= 1
        scripts[ticket] = call
        return ticket
    }

    private func reply(_ call: HostActCall, _ values: [HostValue]) {
        core.reply(call, values)
    }

    /// Fails an act: a caller waiting on it throws the reason, and one nobody waits for is logged.
    private func fail(_ call: HostActCall, _ reason: String) {
        core.fail(call, reason, log: { AndroidLog.error($0) })
    }
}
