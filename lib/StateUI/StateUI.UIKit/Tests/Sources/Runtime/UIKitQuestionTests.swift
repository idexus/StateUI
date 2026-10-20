// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A button offering a choice with no cancel, and the choice it was answered.
private struct Choosing: View {
    @Environment(\.window) private var window
    @State private var answer = "-"

    var body: some View {
        VStack {
            Button("Share").onClicked(gate: .ignoreWhileRunning) {
                answer = try await window.chooseAction("Share via", buttons: ["Mail", "Message"]) ?? "none"
            }
            Text(answer)
        }
    }
}

/// Questions for the user in UIKit's own alert.
@MainActor
final class UIKitQuestionTests: XCTestCase {
    /// A choice standing as a popover - on an iPad - that the user taps away answers that nothing was chosen, and
    /// the next question comes.
    @MainActor
    func testAChoiceTappedAwayAnswersNothingChosen() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("a choice stands as a popover on an iPad") }
        let host = UIKitRenderer.running { Choosing() }
        defer { host.finish() }
        host.views(UIKitButtonView.self).first?.sendActions(for: .primaryActionTriggered)
        host.settle { host.actToolkit.showing?.alert.viewIfLoaded?.window != nil }
        let asked = try XCTUnwrap(host.actToolkit.showing)
        let popover = try XCTUnwrap(asked.alert.popoverPresentationController)

        asked.alert.dismiss(animated: false)
        popover.delegate?.presentationControllerDidDismiss?(popover)
        host.settle { host.views(UIKitTextView.self).last?.attributedText?.string != "-" }

        XCTAssertEqual(host.views(UIKitTextView.self).last?.attributedText?.string, "none")
        XCTAssertNil(host.actToolkit.showing, "the question went")
    }
}
