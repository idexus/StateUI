// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import Foundation
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The UIKit host: an application's iOS head hands it the process, and it runs the application's scenes in the
/// windows iOS opens.
///
///     import NotesUI
///     import StateUIUIKit
///
///     registerApplication()
///     StateUIUIKit.run()
@MainActor
public enum StateUIUIKit {
    /// Runs the application on UIKit's main loop, which never returns.
    ///
    ///     StateUIUIKit.run(delegate: AppDelegate.self)
    ///
    /// - Parameters:
    ///   - resourceDirectory: where the application's pictures are; the bundle's `Images` where nil.
    ///   - delegate: the application's delegate - the host's own, or one of the application's subclassing it, for
    ///     an SDK that asks for one.
    public static func run(
        resourceDirectory: URL? = nil, delegate: StateUIApplicationDelegate.Type = StateUIApplicationDelegate.self
    ) -> Never {
        UIKitRenderer.resourceDirectory = resourceDirectory
            ?? Bundle.main.resourceURL?.appendingPathComponent("Images", isDirectory: true)
        exit(UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(delegate)))
    }
}
#endif
