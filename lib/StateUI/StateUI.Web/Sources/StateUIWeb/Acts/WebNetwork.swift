// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The Web's part of the requests the application sends (`HostActs.network`): the browser's `fetch`, an address
/// with no scheme read against the page's, the browser keeping the page's cookies.
/// Design: docs/design/core/acts.md#requests
@MainActor
final class WebNetwork: NetworkToolkit {
    var readsRelativeAddresses: Bool { true }

    func send(_ request: HostRequest, answered: @escaping (Result<HostResponse, ActFailure>) -> Void) {
        WebRelay.send(request, WebRelay.once {
            guard WebRelay.requestAnswered else { return answered(.failure(ActFailure(WebRelay.requestWords))) }
            let words = WebRelay.requestWords.split(separator: "\u{1F}", omittingEmptySubsequences: false)
                .map(String.init)
            let headers = stride(from: 0, to: words.count - 1, by: 2).map {
                HostHeader(name: words[$0], value: words[$0 + 1])
            }
            let status = WebRelay.requestStatus
            answered(.success(HostResponse(status: status, headers: headers, body: WebRelay.requestBody)))
        })
    }
}
