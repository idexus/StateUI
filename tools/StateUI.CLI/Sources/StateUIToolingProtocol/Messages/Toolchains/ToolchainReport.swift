// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What the machine has of everything it needs: `toolchain/check`'s answer and `stateui doctor`'s.
public struct ToolchainReport: Codable, Equatable, Sendable {
    /// A finding a component, in the order they are checked.
    public var findings: [ToolFinding]

    /// A report of `findings`.
    public init(findings: [ToolFinding]) {
        self.findings = findings
    }

    /// Whether something `host` cannot be built without is missing - with no host, something every host needs.
    public func lacks(for host: HostFamily?) -> Bool {
        findings.contains { finding in
            finding.found == nil && (host.map(finding.hosts.contains) ?? (finding.hosts.count == HostFamily.allCases.count))
        }
    }
}
