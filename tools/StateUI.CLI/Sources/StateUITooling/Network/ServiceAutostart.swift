// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The service started with its user's desktop session, as each system starts a user's own program there - a launch
/// agent on a Mac, a user unit of the graphical session on Linux, the user's `Run` value on Windows, with no window -
/// and on a Mac and Linux again should it end; started at once too. On Windows its port is opened in the firewall to
/// the local subnet alone, which UAC asks once.
/// Design: docs/design/tooling/service.md#the-service-in-the-background
public struct ServiceAutostart: Sendable {
    /// The launch agent's label on a Mac, the unit's name on Linux.
    static let name = "com.stateui.service"
    private let home: URL

    /// The autostart of the user whose home is `home`.
    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
    }

    /// Where the system keeps what starts it, on a Mac and Linux.
    var file: URL {
        #if os(macOS)
        home.appendingPathComponent("Library/LaunchAgents/\(Self.name).plist")
        #else
        home.appendingPathComponent(".config/systemd/user/stateui.service")
        #endif
    }

    /// The user's key of what Windows starts at logon, and the value naming the service.
    static let runKey = #"HKCU\Software\Microsoft\Windows\CurrentVersion\Run"#
    static let runValue = "StateUI"

    /// The command Windows starts the service with: in a console of no window.
    static func windowsCommand(program: String, listen: String) -> String {
        #""C:\Windows\System32\conhost.exe" --headless "\#(program)" service --listen \#(listen)"#
    }

    /// The rule's name in Windows' firewall.
    static let ruleName = "StateUI service"

    /// The PowerShell that opens the service's port: every rule Windows laid for `program` taken away - its own alert's
    /// Allow or Block for any address - and one allowing TCP `port` to it from the local subnet alone laid.
    static func firewallScript(program: String, port: UInt16) -> String {
        """
        $ErrorActionPreference = 'Stop'
        Get-NetFirewallApplicationFilter -Program '\(program)' -ErrorAction SilentlyContinue | Get-NetFirewallRule | Remove-NetFirewallRule
        Get-NetFirewallRule -DisplayName '\(ruleName)' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
        New-NetFirewallRule -DisplayName '\(ruleName)' -Direction Inbound -Action Allow -Program '\(program)' -Protocol TCP -LocalPort \(port) -RemoteAddress LocalSubnet -Profile Any | Out-Null
        """
    }

    /// `script` as PowerShell's `-EncodedCommand` takes it: base64 of its UTF-16LE - no quote a command line could break.
    static func encoded(_ script: String) -> String {
        Data(script.utf16.flatMap { [UInt8(truncatingIfNeeded: $0), UInt8(truncatingIfNeeded: $0 >> 8)] }).base64EncodedString()
    }

    /// The PowerShell that answers whether the service's rule stands.
    static let ruleStands = "if (Get-NetFirewallRule -DisplayName '\(ruleName)' -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }"

    /// `program`'s path as Windows writes it.
    static func windowsPath(_ program: URL) -> String {
        program.path.replacingOccurrences(of: "/", with: "\\")
    }

    /// What `file` holds for `program` serving on `listen`.
    func contents(program: URL, listen: String, log: URL) throws -> Data {
        #if os(macOS)
        let agent: [String: Any] = [
            "Label": Self.name, "ProgramArguments": [program.path, "service", "--listen", listen],
            "RunAtLoad": true, "KeepAlive": true, "StandardOutPath": log.path, "StandardErrorPath": log.path,
        ]
        return try PropertyListSerialization.data(fromPropertyList: agent, format: .xml, options: 0)
        #else
        let unit = """
            [Unit]
            Description=StateUI's tool service
            PartOf=graphical-session.target
            After=graphical-session.target

            [Service]
            ExecStart="\(program.path)" service --listen \(listen)
            Restart=on-failure

            [Install]
            WantedBy=graphical-session.target

            """
        return Data(unit.utf8)
        #endif
    }

    /// Lays what starts `program` serving on `listen` with the user's session, and starts it now; one laid before is
    /// replaced.
    public func install(program: URL, listen: String) async throws {
        #if os(Windows)
        let (_, port) = try ServiceListener.place(listen)
        let exe = Self.windowsPath(program)
        if (try? await run("powershell", ["-NoProfile", "-Command", Self.ruleStands])) == nil {
            let elevated = "$p = Start-Process powershell -Verb RunAs -PassThru -Wait -WindowStyle Hidden -ArgumentList '-NoProfile', "
                + "'-EncodedCommand', '\(Self.encoded(Self.firewallScript(program: exe, port: port)))'; exit $p.ExitCode"
            let opened = (try? await run("powershell", ["-NoProfile", "-Command", elevated])) != nil
            guard opened, (try? await run("powershell", ["-NoProfile", "-Command", Self.ruleStands])) != nil else {
                throw ToolingError(.toolFailed, "Windows' firewall was not opened to the service: UAC asks on this machine's desktop, and was not granted.")
            }
        }
        _ = try? await uninstall()
        try await run("reg", ["add", Self.runKey, "/v", Self.runValue, "/t", "REG_SZ", "/d", Self.windowsCommand(program: exe, listen: listen), "/f"])
        try await run("powershell", ["-NoProfile", "-Command",
            "Start-Process -WindowStyle Hidden -FilePath 'C:\\Windows\\System32\\conhost.exe' -ArgumentList '--headless', '\"\(exe)\"', 'service', '--listen', '\(listen)'"])
        #else
        let log = BuildPermit.userFolder.appendingPathComponent("service/service.log")
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents(program: program, listen: listen, log: log).write(to: file, options: .atomic)
        #if os(macOS)
        let domain = "gui/\(getuid())"
        _ = try? await run("launchctl", ["bootout", domain, file.path])
        try await run("launchctl", ["bootstrap", domain, file.path])
        #else
        try await run("systemctl", ["--user", "daemon-reload"])
        try await run("systemctl", ["--user", "enable", "--now", "stateui.service"])
        try await run("systemctl", ["--user", "restart", "stateui.service"])
        #endif
        #endif
    }

    /// Stops the service and takes away what starts it; whether one was laid.
    @discardableResult
    public func uninstall() async throws -> Bool {
        #if os(Windows)
        let laid = (try? await run("reg", ["query", Self.runKey, "/v", Self.runValue])) != nil
        if laid { try await run("reg", ["delete", Self.runKey, "/v", Self.runValue, "/f"]) }
        if let running = ServiceState.running() { _ = try? await run("taskkill", ["/PID", String(running.process), "/F"]) }
        return laid
        #else
        guard FileManager.default.fileExists(atPath: file.path) else { return false }
        #endif
        #if os(macOS)
        _ = try? await run("launchctl", ["bootout", "gui/\(getuid())", file.path])
        try FileManager.default.removeItem(at: file)
        #elseif !os(Windows)
        _ = try? await run("systemctl", ["--user", "disable", "--now", "stateui.service"])
        try FileManager.default.removeItem(at: file)
        _ = try? await run("systemctl", ["--user", "daemon-reload"])
        #endif
        return true
    }

    @discardableResult
    private func run(_ program: String, _ arguments: [String]) async throws -> String {
        let said = Gathered()
        let outcome = try await ProcessRunner().run(
            ProcessRequest(.name(program), arguments: arguments, timeout: .seconds(60)), output: said.add)
        let text = (said.lines(of: .standardOutput) + said.lines(of: .standardError)).joined(separator: "\n")
        guard outcome.succeeded else {
            throw ToolingError(.toolFailed, "\(program) \(arguments.joined(separator: " ")) failed:\n\(text)")
        }
        return text
    }
}
