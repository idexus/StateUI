// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A picture is read from the application's images and measured in points.
@MainActor
final class UIKitImageViewTests: XCTestCase {
    /// An SVG of 40 by 20 points, drawn three times over; a PNG of 6 by 4 pixels kept at a pixel a point; a name
    /// with no picture, which takes no room.
    @MainActor
    func testAPictureIsMeasuredAtItsOwnSizeInPoints() {
        let host = UIKitRenderer.running {
            VStack {
                Image("test_wide.png").horizontalAlignment(.start)
                Image("test_dot.png").horizontalAlignment(.start)
                Image("nowhere.png").horizontalAlignment(.start)
            }
        }
        defer { host.finish() }

        let images = host.views(UIKitImageView.self)
        XCTAssertEqual(images.count, 3)
        XCTAssertEqual(images.map(\.frame), [
            CGRect(x: 0, y: 0, width: 40, height: 20), CGRect(x: 0, y: 20, width: 6, height: 4),
            CGRect(x: 0, y: 24, width: 0, height: 0),
        ])
        XCTAssertEqual(images[0].image?.scale, 3, "the SVG's drawing, three pixels a point")
    }

    /// SVGs a second window shows cost it little: the pictures of the first window, shown again in a scene of their
    /// own, add megabytes. An iPad gives an application a second scene.
    @MainActor
    func testASecondWindowShowingSVGsCostsLittle() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("an iPhone shows one window") }
        let host = UIKitRenderer.running { PicturesApplication() }
        host.ownsScenes = true
        TestScene.connecting = { host.connect($0) }
        defer {
            host.closeTheOtherScenes()
            host.finish()
        }
        let open = try XCTUnwrap(host.views(UIKitButtonView.self).first)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1))
        let before = Self.footprint()

        open.sendActions(for: .touchUpInside)
        host.settle { host.roster.windows.count == 2 && host.roster.windows.allSatisfy { $0.1.window != nil } }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1))
        let grown = Self.footprint() - before

        let second = try XCTUnwrap(host.roster.windows.last?.1.window)
        XCTAssertFalse(second.windowScene === TestScene.scene, "a scene of its own")
        XCTAssertEqual(host.views(UIKitImageView.self).filter { $0.image?.scale == 3 }.count, 34)
        XCTAssertLessThan(grown, 200 << 20, "the second window took \(grown >> 20) MB")
    }

    /// The memory the system counts against this process: its footprint.
    private static func footprint() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.phys_footprint) : 0
    }
}

/// An application whose first window shows a run of SVGs and opens a second window showing them again.
private struct PicturesApplication: Application {
    var body: some Scene { PicturesScene() }
}

private struct PicturesScene: Scene {
    var body: some Scene {
        WindowGroup { PicturesPage(opens: true) }
        Window(WindowType("pictures.again")) { PicturesPage(opens: false) }
    }
}

private struct PicturesPage: View {
    let opens: Bool

    @Environment(\.application) private var application

    var body: some View {
        let application = self.application
        return VStack {
            if opens {
                Button("Open").onClicked(.ignoreWhileRunning) { try await application.openWindow(WindowType("pictures.again")) }
            }
            ForEach(Array(0..<17)) { _ in
                Image("test_wide.svg").width(177).height(248)
            }
        }
    }
}
