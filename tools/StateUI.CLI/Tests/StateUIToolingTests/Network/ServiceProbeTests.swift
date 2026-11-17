// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class ServiceProbeTests: XCTestCase {
    /// A probe tells a stateui service from a place answering none; a check of a paired machine says it admitted this
    /// one and what it builds, or that its pairing is gone.
    func testAProbeTellsAServiceAndACheckItsAdmission() async throws {
        let state = FileManager.default.temporaryDirectory.appendingPathComponent("probe-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: state) }
        let pairing = try ServicePairing(file: state.appendingPathComponent("clients.json"), name: "Office")
        let listener = try ServiceListener.open(on: "127.0.0.1", port: 0, pairing: pairing)
        let serving = Task { await listener.serve() }
        defer { serving.cancel() }

        let answered = await ServiceProbe.probe("127.0.0.1", port: listener.port)
        XCTAssertNil(answered)
        let closed = try StreamSocket.listen(on: "127.0.0.1", port: 0)
        let nobody = closed.port
        closed.close()
        let unanswered = await ServiceProbe.probe("127.0.0.1", port: nobody)
        XCTAssertNotNil(unanswered)

        let machine = try await RemoteMachines(file: state.appendingPathComponent("remotes.json"))
            .pair(name: "office", address: "127.0.0.1", port: listener.port, code: pairing.code)
        guard case .admitted(let info) = await ServiceProbe.check(machine) else { return XCTFail("not admitted") }
        XCTAssertEqual(info.hosts, HostPlaces.here)
        var forgotten = machine
        forgotten.token = String(repeating: "0", count: 64)
        guard case .notAdmitted = await ServiceProbe.check(forgotten) else { return XCTFail("a wrong token was admitted") }
        var gone = machine
        gone.port = nobody
        guard case .unreached = await ServiceProbe.check(gone) else { return XCTFail("a closed port answered") }
    }
}
