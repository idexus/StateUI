// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// WinUI's part of the requests the application sends (`HostActs.network`): Windows' own HTTP client, in the relay's
/// Requests.cpp. Each answers later, by the ticket it was handed.
/// Design: docs/design/core/acts.md#requests
@MainActor
final class WinUINetwork: NetworkToolkit {
    /// What hears each request's answer, by ticket.
    private let requests = Numbered<(Result<HostResponse, ActFailure>) -> Void>()

    func send(
        _ request: HostRequest, answered: @escaping (Result<HostResponse, ActFailure>) -> Void
    ) -> () -> Void {
        let ticket = requests.hold(answered)
        let headers = request.headers.flatMap { [$0.name, $0.value] }.joined(separator: "\u{1F}")
        request.body.withUnsafeBufferPointer { body in
            stateui_winui_send_request(
                ticket, request.address, request.method, headers, body.baseAddress, Int64(body.count))
        }
        return { stateui_winui_cancel_request(ticket) }
    }

    /// The request under `ticket` was answered: its status, its headers' names and values in turn a unit separator
    /// apart, and its body; or why no answer came.
    func answered(ticket: Int64, status: Int, headers: String, body: [UInt8], failure: String?) {
        let words = headers.isEmpty ? [] : headers.split(separator: "\u{1F}", omittingEmptySubsequences: false)
            .map(String.init)
        let said = stride(from: 0, to: words.count - 1, by: 2).map { HostHeader(name: words[$0], value: words[$0 + 1]) }
        requests.take(ticket)?(failure.map { .failure(ActFailure($0)) }
            ?? .success(HostResponse(status: status, headers: said, body: body)))
    }
}
