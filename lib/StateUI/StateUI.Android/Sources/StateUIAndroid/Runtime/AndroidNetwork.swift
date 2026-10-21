// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// Android's part of the requests the application sends (`HostActs.network`): the platform's HTTP connection beside
/// the UI thread, in the Java layer's `StateUIRequests`. Each answers later, by the ticket it was handed.
/// Design: docs/design/core/acts.md#requests
@MainActor
final class AndroidNetwork: NetworkToolkit {
    /// What hears each request's answer, by ticket.
    private let requests = Numbered<(Result<HostResponse, ActFailure>) -> Void>()

    func send(_ request: HostRequest, answered: @escaping (Result<HostResponse, ActFailure>) -> Void) {
        let ticket = requests.hold(answered)
        Java.frame {
            Java.callStatic(
                JavaAPI.requests, JavaAPI.sendRequest, .long(ticket), .object(Java.string(request.address)),
                .object(Java.string(request.method)),
                .object(Java.strings(request.headers.flatMap { [$0.name, $0.value] })), .object(Java.bytes(request.body)))
        }
    }

    /// The request under `ticket` was answered: its status, its headers as names and values in turn and its body,
    /// or why no answer came.
    func answered(ticket: Int64, status: Int, headers: [String], body: [UInt8], failure: String?) {
        let said = stride(from: 0, to: headers.count - 1, by: 2).map {
            HostHeader(name: headers[$0], value: headers[$0 + 1])
        }
        requests.take(ticket)?(failure.map { .failure(ActFailure($0)) }
            ?? .success(HostResponse(status: status, headers: said, body: body)))
    }
}
