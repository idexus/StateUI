// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the application asks of a server, through the platform's own networking.
// Design: docs/design/core/acts.md#requests

extension ApplicationSession {
    /// Sends `request` through the platform's own networking and answers what the server said.
    ///
    ///     @Environment(\.application) private var application
    ///
    ///     Button("Weather").onClicked(.cancelPrevious) {
    ///         let response = try await application.send(HTTPRequest(
    ///             "https://api.open-meteo.com/v1/forecast?latitude=50.06&longitude=19.94&current=temperature_2m"))
    ///         said = response.status == 200 ? response.text : "status \(response.status)"
    ///     }
    ///
    /// Any status is an answer, a 404 included; what throws is no answer at all - no connection, no server, an
    /// address the platform cannot read. The platform keeps the cookies a server sets, as a browser does, so a
    /// session a server opens holds for the requests after it.
    ///
    /// - Parameter request: what to send, and where.
    /// - Returns: what the server answered.
    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let headers = request.headers.sorted { $0.key < $1.key }.flatMap { [$0.key, $0.value] }
        let (status, said, body) = try await stateUICall(
            ApplicationContract.sendRequest, request.address, Name(request.method.name), headers, request.body)
        let pairs = stride(from: 0, to: said.count - 1, by: 2).map { (said[$0], said[$0 + 1]) }
        return HTTPResponse(status: status, headers: Dictionary(pairs) { "\($0), \($1)" }, body: body)
    }
}
