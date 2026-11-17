// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class ServiceAutostartTests: XCTestCase {
    /// On a Mac a launch agent starts the service at login and again should it end; on Linux a user unit of the
    /// graphical session, which hands it the desktop's display and bus.
    func testTheSystemStartsTheServiceWithTheSession() throws {
        let home = URL(fileURLWithPath: "/Users/me")
        let laid = try ServiceAutostart(home: home)
            .contents(program: URL(fileURLWithPath: "/opt/stateui"), listen: "0.0.0.0:7979", log: URL(fileURLWithPath: "/tmp/service.log"))
        #if os(macOS)
        let agent = try XCTUnwrap(PropertyListSerialization.propertyList(from: laid, format: nil) as? [String: Any])
        XCTAssertEqual(agent["ProgramArguments"] as? [String], ["/opt/stateui", "service", "--listen", "0.0.0.0:7979"])
        XCTAssertEqual(agent["RunAtLoad"] as? Bool, true)
        XCTAssertEqual(agent["KeepAlive"] as? Bool, true)
        XCTAssertEqual(ServiceAutostart(home: home).file.path, "/Users/me/Library/LaunchAgents/com.stateui.service.plist")
        #elseif os(Linux)
        let unit = String(decoding: laid, as: UTF8.self)
        XCTAssertTrue(unit.contains(#"ExecStart="/opt/stateui" service --listen 0.0.0.0:7979"#), unit)
        XCTAssertTrue(unit.contains("WantedBy=graphical-session.target"), unit)
        #endif
    }

    /// On Windows the service starts at logon in a console of no window, and its port opens to the local subnet alone
    /// - every rule Windows laid for the program taken away - by a script no command line's quoting can break.
    func testWindowsOpensThePortToTheSubnetByAnEncodedScript() throws {
        let program = #"C:\Users\Jan Kowalski\stateui-guest\bin\stateui.exe"#
        XCTAssertEqual(
            ServiceAutostart.windowsCommand(program: program, listen: "0.0.0.0:7979"),
            #""C:\Windows\System32\conhost.exe" --headless "C:\Users\Jan Kowalski\stateui-guest\bin\stateui.exe" service --listen 0.0.0.0:7979"#)
        let script = ServiceAutostart.firewallScript(program: program, port: 7979)
        XCTAssertTrue(script.contains("Get-NetFirewallApplicationFilter -Program '\(program)'"), script)
        XCTAssertTrue(script.contains("-LocalPort 7979 -RemoteAddress LocalSubnet"), script)
        let encoded = ServiceAutostart.encoded(script)
        XCTAssertFalse(encoded.contains(" ") || encoded.contains("\"") || encoded.contains("'"))
        let bytes = try XCTUnwrap(Data(base64Encoded: encoded))
        let units = stride(from: 0, to: bytes.count, by: 2).map { UInt16(bytes[$0]) | UInt16(bytes[$0 + 1]) << 8 }
        XCTAssertEqual(String(decoding: units, as: UTF16.self), script)
    }

    /// A running service says where it listens and its code; one whose port answers no more is no service.
    func testAServiceIsRunningWhileItsPortAnswers() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("service-\(UUID().uuidString)/state.json")
        addTeardownBlock { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let listener = try StreamSocket.listen(on: "127.0.0.1", port: 0)
        let state = ServiceState(address: "127.0.0.1", port: listener.port, code: "123456", codeUntil: Date(timeIntervalSince1970: 1_800_000_000))
        try state.write(to: file)
        XCTAssertEqual(ServiceState.running(in: file), state)
        listener.close()
        XCTAssertNil(ServiceState.running(in: file))
    }
}
