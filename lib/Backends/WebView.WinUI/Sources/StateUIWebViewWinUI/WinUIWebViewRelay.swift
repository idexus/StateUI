// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CWebViewWinUI
@_spi(Host) import StateUIHost
import StateUI

/// What the relay's web views tell their Swift halves - each reached by the number it was made with - and the
/// scripts waiting for their answers, by ticket.
@MainActor
enum WinUIWebViewRelay {
    private static let views = LiveViews<WinUIWebView>()
    private static let scripts = Numbered<CheckedContinuation<String?, any Error>>()
    private static var listening = false

    /// What a script that did not run throws.
    struct ScriptDidNotRun: Error, CustomStringConvertible {
        var description: String { "the script did not run" }
    }

    static func reserve() -> Int64 {
        views.reserve()
    }

    static func hold(_ view: WinUIWebView, as number: Int64) {
        views.hold(view, as: number)
    }

    static func forget(_ number: Int64) {
        views.release(number)
    }

    /// Keeps `answer` until the script under the ticket this answers ran.
    static func wait(_ answer: CheckedContinuation<String?, any Error>) -> Int64 {
        scripts.hold(answer)
    }

    private static func view(_ number: Int64) -> WinUIWebView? {
        views.find(number)
    }

    /// Hands the relay what it tells, once.
    static func listen() {
        guard !listening else { return }
        listening = true
        var callbacks = WebViewWinUICallbacks(
            navigating: { view, told, utf8 in
                let address = utf8.map { String(cString: $0) } ?? ""
                MainActor.assumeIsolated {
                    WinUIWebViewRelay.view(view)?.navigating(
                        told: WebNavigationType(rawValue: told) ?? .unknown, to: address)
                }
            },
            navigated: { view, result, utf8 in
                let address = utf8.map { String(cString: $0) } ?? ""
                MainActor.assumeIsolated {
                    WinUIWebViewRelay.view(view)?.navigated(WebNavigationResult(rawValue: result) ?? .unknown, at: address)
                }
            },
            history: { view, back, forward in
                MainActor.assumeIsolated { WinUIWebViewRelay.view(view)?.historyChanged(back: back, forward: forward) }
            },
            ended: { view in
                MainActor.assumeIsolated { WinUIWebViewRelay.view(view)?.ended() }
            },
            answered: { ticket, ran, json in
                let words = json.map { String(cString: $0) }
                MainActor.assumeIsolated {
                    guard let answer = WinUIWebViewRelay.scripts.take(ticket) else { return }
                    guard ran else { return answer.resume(throwing: ScriptDidNotRun()) }
                    answer.resume(returning: ScriptAnswer.text(json: words))
                }
            },
            unstarted: { view in
                MainActor.assumeIsolated { WinUIWebViewRelay.view(view)?.unstarted() }
            })
        stateui_webview_winui_set_callbacks(&callbacks)
    }
}
