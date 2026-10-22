// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A view's popover as UIKit presents it.
@MainActor
final class UIKitPopoverTests: XCTestCase {
    /// What a popover holds stands within its safe area, clear of the arrow UIKit draws over one of its edges: its
    /// padding whole on every side. iOS 26 lays the popover's view under its arrow and says so by the safe area -
    /// iOS 27 moves the view itself - so these tell on an iOS 26 simulator.
    @MainActor
    func testAPopoversContentStandsClearOfItsArrow() throws {
        let host = UIKitRenderer.running(reducesMotion: true) {
            VStack {
                Button("Filters").popover(isPresented: State(wrappedValue: true).projectedValue) {
                    Text("Inside").padding(16)
                }
            }
        }
        defer { host.finish() }
        let root = try XCTUnwrap(host.roster.windows.first?.1.window?.rootViewController)
        host.settle {
            root.presentedViewController?.viewIfLoaded?.window != nil
                && root.presentedViewController?.transitionCoordinator == nil
        }
        let shown = try XCTUnwrap(root.presentedViewController?.view)
        let content = try XCTUnwrap((host.runtime.tree.root?.first(type: .popover)?.native as? UIKitElement)?.view)
        shown.layoutIfNeeded()

        XCTAssertEqual(content.convert(content.bounds, to: shown), shown.bounds.inset(by: shown.safeAreaInsets))
    }

    /// What a popover holds lets itself under the arrow where its layout says so, out to the popover's edges - its
    /// background behind the arrow too.
    @MainActor
    func testAPopoversContentRunsUnderItsArrowWhereItSaysSo() throws {
        let host = UIKitRenderer.running(reducesMotion: true) {
            VStack {
                Button("Filters").popover(isPresented: State(wrappedValue: true).projectedValue) {
                    VStack { Text("Inside") }.padding(16).ignoresSafeArea(.all)
                }
            }
        }
        defer { host.finish() }
        let root = try XCTUnwrap(host.roster.windows.first?.1.window?.rootViewController)
        host.settle {
            root.presentedViewController?.viewIfLoaded?.window != nil
                && root.presentedViewController?.transitionCoordinator == nil
        }
        let shown = try XCTUnwrap(root.presentedViewController?.view)
        let content = try XCTUnwrap((host.runtime.tree.root?.first(type: .popover)?.native as? UIKitElement)?.view)
        shown.layoutIfNeeded()

        XCTAssertEqual(content.convert(content.bounds, to: shown), shown.bounds, "out to the popover's edges")
    }
}
