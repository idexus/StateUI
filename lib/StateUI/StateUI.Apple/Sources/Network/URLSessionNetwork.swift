// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The requests an application sends on Apple's platforms (`HostActs.network`): the system's shared `URLSession`,
/// which keeps the cookies a server sets in the system's store.
/// Design: docs/design/core/acts.md#requests
@_spi(Host) @MainActor public final class URLSessionNetwork: NetworkToolkit {
    /// A toolkit sending through the shared session.
    public init() {}

    public func send(_ request: HostRequest, answered: @escaping (Result<HostResponse, ActFailure>) -> Void) {
        guard let address = URL(string: request.address) else {
            return answered(.failure(ActFailure("'\(request.address)' is no address")))
        }
        var asked = URLRequest(url: address)
        asked.httpMethod = request.method
        for header in request.headers { asked.addValue(header.value, forHTTPHeaderField: header.name) }
        if !request.body.isEmpty { asked.httpBody = Data(request.body) }

        Task { @MainActor in
            do {
                let (body, response) = try await URLSession.shared.data(for: asked)
                guard let response = response as? HTTPURLResponse else {
                    return answered(.failure(ActFailure("'\(request.address)' answered with no HTTP status")))
                }
                let headers = response.allHeaderFields.compactMap { name, value in
                    (name as? String).map { HostHeader(name: $0, value: "\(value)") }
                }
                answered(.success(HostResponse(status: response.statusCode, headers: headers, body: Array(body))))
            } catch {
                answered(.failure(ActFailure(error.localizedDescription)))
            }
        }
    }
}
