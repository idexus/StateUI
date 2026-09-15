// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// Performs the acts the application calls on the host, and answers each: a
/// reply with its values, or a failure with the reason, so a caller never
/// waits on an act nobody performs.
///
/// An act about a view names it at argument 0 - by the number the differ gave
/// it, or by the name its author did - and the view is found in the mounted
/// tree as it stands; one not being shown fails with that reason.
///
/// THE FOCUS IS THE PLATFORM'S: the host asks the window who holds it and
/// never mirrors that identity as state. `focus` answers whether the view took
/// it - false is an answer, not a failure: a view disabled, off screen or with
/// nothing to type into refuses it. `hideOnScreenKeyboard` takes the focus off
/// whatever holds it in the window the reader is looking at, answering whether
/// anything did.
@MainActor
final class AppKitActPerformer {
    private let core = AppKitCoreLink()
    private unowned let renderer: AppKitRenderer

    /// A performer for the acts `renderer`'s application calls.
    init(renderer: AppKitRenderer) {
        self.renderer = renderer
    }

    /// Performs one act, and answers it.
    func perform(_ call: HostActCall) {
        switch call.act {
        case .persistValue:
            renderer.savePersistent(call)

        case .persistSceneValue:
            renderer.keepSceneValue(call)

        case .handlerFailed:
            NSLog("StateUI AppKit: a handler failed: %@", call.arguments.first?.string ?? "")

        case .focus, .unfocus:
            aim(call)

        case .hideOnScreenKeyboard:
            reply(call, [.bool(hideKeyboard())])

        default:
            fail(call, "the AppKit host does not perform the act '\(call.act.name)'")
        }
    }

    /// Puts the keyboard on the view the act names, or takes it off.
    private func aim(_ call: HostActCall) {
        guard let target = Self.target(of: call) else {
            fail(call, "a focus act has to say which view it is for")
            return
        }
        guard let view = renderer.presentedView(id: target) else {
            fail(call, "there is no view \(target) on screen")
            return
        }

        if call.act == .unfocus {
            if let window = view.window, AppKitFocus.holds(view, window.firstResponder) {
                window.makeFirstResponder(nil)
            }
            reply(call, [])
            return
        }

        guard let window = view.window, let focusable = AppKitFocus.focusable(in: view) else {
            reply(call, [.bool(false)])
            return
        }
        reply(call, [.bool(window.makeFirstResponder(focusable))])
    }

    /// Takes the focus off whatever holds it in the window the reader is
    /// looking at; whether anything did.
    private func hideKeyboard() -> Bool {
        guard let window = renderer.readerWindow,
              let holder = window.firstResponder as? NSView,
              holder !== window.contentView
        else { return false }

        return window.makeFirstResponder(nil)
    }

    private func reply(_ call: HostActCall, _ values: [HostValue]) {
        if let completion = call.completion {
            _ = core.reply(completion, with: values)
        }
    }

    /// Fails an act: a caller waiting on it throws the reason, and one nobody
    /// waits for is logged, so neither passes in silence.
    private func fail(_ call: HostActCall, _ reason: String) {
        if let completion = call.completion {
            _ = core.fail(completion, reason: reason)
        } else {
            NSLog("StateUI AppKit: %@", reason)
        }
    }

    /// The view an act names at argument 0: by the differ's number, or by the
    /// author's name.
    static func target(of call: HostActCall) -> ElementId? {
        switch call.arguments.first {
        case .string(let name)?: .manual(name)
        case .number(let number)?: .auto(Int(number))
        default: nil
        }
    }
}
#endif
