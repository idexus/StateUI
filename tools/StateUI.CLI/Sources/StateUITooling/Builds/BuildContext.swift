// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// One build's identity - an application's product for a host and an architecture, by a compiler against an SDK
/// and a library - and the scratch folder it alone writes: `.build/<host>/<architecture>-<key>`.
/// Design: docs/design/tooling/builds.md#a-builds-context
public struct BuildContext: Hashable, Sendable {
    /// The application's folder, its real path.
    public var application: URL
    /// The product built: `GalleryAppKit`.
    public var product: String
    public var host: HostFamily
    public var configuration: BuildConfiguration
    public var architecture: Architecture
    /// The compiler, as it names itself: the first line of `swift --version`.
    public var compiler: String
    /// The platform SDK the host builds against - its version and path - or empty where the host has none.
    public var sdk: String
    /// The StateUI checkout the application builds with, its real path.
    public var library: URL

    /// A build of `product` of `application` for `host`.
    public init(
        application: URL, product: String, host: HostFamily, configuration: BuildConfiguration,
        architecture: Architecture, compiler: String, sdk: String, library: URL
    ) {
        self.application = application
        self.product = product
        self.host = host
        self.configuration = configuration
        self.architecture = architecture
        self.compiler = compiler
        self.sdk = sdk
        self.library = library
    }

    /// What tells two scratch folders apart: the architecture, then a digest of the compiler, the SDK and the
    /// library - never the configuration, which SwiftPM keeps apart inside one scratch folder.
    public var key: String {
        let identity = [compiler, sdk, library.path].joined(separator: "\n")
        return "\(architecture.rawValue)-\(Self.digest(identity))"
    }

    /// The published artifact this build replaces: its host, its key and its configuration.
    public var artifact: String { "\(host.rawValue)-\(key)-\(configuration.rawValue)" }

    /// The head's own package, which builds the application for its host: `<application>/Platforms/<Host>`.
    public var head: URL {
        application.appendingPathComponent("Platforms").appendingPathComponent(host.folder)
    }

    /// The SwiftPM scratch folder this build writes: `<application>/.build/<host>/<key>`.
    public var scratch: URL {
        application.appendingPathComponent(".build").appendingPathComponent(host.rawValue).appendingPathComponent(key)
    }

    /// FNV-1a over `text`'s UTF-8, twelve hex digits: a cache's key, the same on every machine and run.
    static func digest(_ text: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(String(hash, radix: 16).leftPadded(to: 16).prefix(12))
    }
}

private extension String {
    func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: "0", count: length - count) + self
    }
}
