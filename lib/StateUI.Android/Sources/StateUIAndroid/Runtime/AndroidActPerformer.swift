// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
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

    /// The acts not answered yet - a question, a script - by ticket.
    private var waiting: [Int64: HostActCall] = [:]

    /// The next ticket: one number across every renderer of the process, so an answer that comes after its
    /// renderer is gone answers nothing of another's.
    private(set) static var nextTicket: Int64 = 1

    init(core: CoreLink, context: JavaObject, root: JavaObject) {
        self.core = core
        self.context = context
        self.root = root
    }

    /// Performs one act, and answers it.
    func perform(_ call: HostActCall, in tree: MountedTree) {
        switch call.act {
        case .currentTime:
            let clock = Java.frame { Java.callStaticObject(JavaAPI.environment, JavaAPI.clock).map(Java.intsOf) } ?? []
            reply(call, [clock.map(Double.init).propValue])
        case .currentTimeZone:
            let zone = Java.frame { Java.text(Java.callStaticObject(JavaAPI.environment, JavaAPI.zone)) }
            reply(call, [.string(zone)])
        case .utcOffset:
            reply(call, [.number(Double(utcOffset(call)))])
        case .alert, .confirm, .chooseAction, .prompt:
            ask(call)
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
            fail(call, "the Android Views host does not perform the act '\(call.act.name)'")
        }
    }

    /// The act under `ticket` was answered: a dialog accepted or not, and the words chosen or typed; a script's
    /// value as text.
    func answered(ticket: Int64, accepted: Bool, words: String?) {
        guard let call = waiting.removeValue(forKey: ticket) else { return }

        switch call.act {
        case .confirm: reply(call, [.bool(accepted)])
        case .chooseAction, .prompt: reply(call, [(accepted ? words : nil).propValue])
        case .evaluateJavaScript: reply(call, [words.propValue])
        default: reply(call, [])
        }
    }

    /// Puts a question to the user in the platform's own dialog; its answer comes back by ticket.
    private func ask(_ call: HostActCall) {
        let ticket = wait(call)
        let arguments = call.arguments

        func text(_ index: Int) -> String? { arguments.value(index)?.string }
        Java.frame {
            let context = context.reference
            switch call.act {
            case .alert:
                Java.callStatic(
                    JavaAPI.dialogs, JavaAPI.alert, .object(context), .long(ticket),
                    .object(Java.string(text(0) ?? "")), .object(Java.string(text(1) ?? "")),
                    .object(Java.string(text(2) ?? "OK")))
            case .confirm:
                Java.callStatic(
                    JavaAPI.dialogs, JavaAPI.confirm, .object(context), .long(ticket),
                    .object(Java.string(text(0) ?? "")), .object(Java.string(text(1) ?? "")),
                    .object(Java.string(text(2) ?? "OK")), .object(Java.string(text(3) ?? "Cancel")))
            case .chooseAction:
                let choices = arguments.value(3).flatMap { [String](propValue: $0) } ?? []
                Java.callStatic(
                    JavaAPI.dialogs, JavaAPI.chooseAction, .object(context), .long(ticket),
                    .object(Java.string(text(0) ?? "")), .object(text(1).flatMap(Java.string)),
                    .object(text(2).flatMap(Java.string)),
                    .object(Java.array(of: JavaAPI.string, choices.map(Java.string))))
            default:
                let purpose = arguments.value(6).flatMap { InputPurpose(propValue: $0) } ?? .default
                Java.callStatic(
                    JavaAPI.dialogs, JavaAPI.prompt, .object(context), .long(ticket),
                    .object(Java.string(text(0) ?? "")), .object(Java.string(text(1) ?? "")),
                    .object(Java.string(text(2) ?? "OK")), .object(Java.string(text(3) ?? "Cancel")),
                    .object(text(4).flatMap(Java.string)),
                    .int(Int32(arguments.value(5)?.number ?? -1)), .int(Self.inputType(purpose)),
                    .object(Java.string(text(7) ?? "")))
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

    /// How far a zone is from UTC on a day, in minutes, as the platform says.
    private func utcOffset(_ call: HostActCall) -> Int32 {
        let zone = call.arguments.value(0)?.string
        let day = call.arguments.value(1).flatMap { CalendarDate(propValue: $0) }
        return Java.frame {
            Java.callStaticInt(
                JavaAPI.environment, JavaAPI.utcOffset, .object(zone.flatMap(Java.string)),
                .int(Int32(day?.year ?? 0)), .int(Int32(day?.month ?? 0)), .int(Int32(day?.day ?? 0)))
        }
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
        default: return web.evaluate(call.arguments.value(1)?.string ?? "", ticket: wait(call))
        }
        reply(call, [])
    }

    /// The view the act is aimed at, which its first argument names; nil, the act failed, where there is none.
    private func aimed(_ call: HostActCall, in tree: MountedTree) -> AndroidView? {
        let target: ElementId? = switch call.arguments.first {
        case .string(let name)?: .manual(name)
        case .number(let number)?: .auto(Int(number))
        default: nil
        }
        guard let target else {
            fail(call, "\(call.act.name) has to say which view it is for")
            return nil
        }
        guard let view = (tree.root?.first(id: target)?.native as? AndroidElement)?.view else {
            fail(call, "there is no view \(target) on screen")
            return nil
        }
        return view
    }

    /// Keeps `call` waiting for its answer, under the ticket this answers.
    private func wait(_ call: HostActCall) -> Int64 {
        let ticket = Self.nextTicket
        Self.nextTicket += 1
        waiting[ticket] = call
        return ticket
    }

    private func reply(_ call: HostActCall, _ values: [HostValue]) {
        if let completion = call.completion { _ = core.reply(completion, with: values) }
    }

    /// Fails an act: a caller waiting on it throws the reason, and one nobody waits for is logged.
    private func fail(_ call: HostActCall, _ reason: String) {
        if let completion = call.completion {
            _ = core.fail(completion, reason: reason)
        } else {
            AndroidLog.error(reason)
        }
    }
}
