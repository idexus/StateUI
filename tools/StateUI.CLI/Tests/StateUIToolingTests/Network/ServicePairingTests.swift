// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import Synchronization
import XCTest

final class ServicePairingTests: XCTestCase {
    private func store() -> URL {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("pairing-\(UUID().uuidString)/clients.json")
        addTeardownBlock { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        return file
    }

    /// The code the service shows pairs one client, then gives way to a new one, which the client kept by the service
    /// survives: a new service on the same file knows it.
    func testACodePairsOneClientThenIsRenewed() throws {
        let file = store()
        let said = Mutex<[String]>([])
        let pairing = ServicePairing(file: file, name: "Office", said: { code in said.withLock { $0.append(code) } })
        let first = pairing.code
        let paired = try pairing.pair(PairingRequest(code: first, client: "Studio"))
        XCTAssertEqual(paired.service, "Office")
        XCTAssertEqual(paired.token.count, 64)
        XCTAssertNotEqual(pairing.code, first)
        XCTAssertEqual(said.withLock { $0 }, [first, pairing.code])
        XCTAssertThrowsError(try pairing.pair(PairingRequest(code: first, client: "Other")))
        let again = ServicePairing(file: file, name: "Office")
        XCTAssertTrue(Self.admits(again, client: paired.client, token: paired.token))
    }

    /// Five wrong codes retire the one shown, and a code ten minutes old pairs no one.
    func testWrongTriesAndTimeRetireACode() throws {
        let clock = Mutex(Date(timeIntervalSince1970: 0))
        let pairing = ServicePairing(file: store(), name: "Office", now: { clock.withLock { $0 } })
        let shown = pairing.code
        for _ in 0..<4 { XCTAssertThrowsError(try pairing.pair(PairingRequest(code: "x", client: "Studio"))) }
        XCTAssertEqual(pairing.code, shown)
        XCTAssertThrowsError(try pairing.pair(PairingRequest(code: "x", client: "Studio")))
        XCTAssertNotEqual(pairing.code, shown)
        let fresh = pairing.code
        clock.withLock { $0 = $0.addingTimeInterval(601) }
        XCTAssertThrowsError(try pairing.pair(PairingRequest(code: fresh, client: "Studio")))
    }

    /// A connection admits a client answering its own challenge with its token, once; a wrong token, a client not
    /// paired, and no challenge asked are refused.
    func testAChallengeAdmitsItsTokenOnce() throws {
        let pairing = ServicePairing(file: store(), name: "Office")
        let paired = try pairing.pair(PairingRequest(code: pairing.code, client: "Studio"))
        XCTAssertTrue(Self.admits(pairing, client: paired.client, token: paired.token))
        XCTAssertFalse(Self.admits(pairing, client: paired.client, token: String(repeating: "0", count: 64)))
        XCTAssertFalse(Self.admits(pairing, client: "nobody", token: paired.token))
        XCTAssertFalse(pairing.admission().admits(Credential(client: paired.client, answer: "")))

        let admission = pairing.admission()
        guard case .result(let asked) = admission.answer("service/challenge", nil) else { return XCTFail("no challenge") }
        let nonce = try asked.decode(Challenge.self).nonce
        let answer = SHA256.hex(SHA256.hmac(key: Array(paired.token.utf8), message: Array(nonce.utf8)))
        XCTAssertTrue(admission.admits(Credential(client: paired.client, answer: answer)))
        XCTAssertFalse(admission.admits(Credential(client: paired.client, answer: answer)), "a challenge answers once")
    }

    /// Whether a fresh connection of `pairing` admits `client` answering its challenge with `token`.
    private static func admits(_ pairing: ServicePairing, client: String, token: String) -> Bool {
        let admission = pairing.admission()
        guard case .result(let asked) = admission.answer("service/challenge", nil),
              let nonce = try? asked.decode(Challenge.self).nonce else { return false }
        return admission.admits(Credential(client: client, answer: SHA256.hex(SHA256.hmac(key: Array(token.utf8), message: Array(nonce.utf8)))))
    }
}
