// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import UIKit
import XCTest

/// A button wears what its style says, and the moment the style leaves it, it looks as a button that never wore one.
@MainActor
final class UIKitButtonLookTests: XCTestCase {
    func testAButtonWhoseStyleLeavesLooksAsOneThatNeverWoreIt() throws {
        let platform = State(wrappedValue: false)
        let host = UIKitRenderer.running { StyledButtons(platform: platform.projectedValue) }
        defer { host.finish() }
        host.layOut()
        let buttons = host.views(UIKitButtonView.self)
        XCTAssertEqual(buttons.count, 2)
        let (styled, plain) = (buttons[0], buttons[1])
        host.settle { styled.configuration?.contentInsets.leading == 30 }
        XCTAssertNotEqual(Self.edge(of: styled), Self.edge(of: plain), "the style's fill")

        platform.wrappedValue = true
        host.settle { styled.configuration?.contentInsets.leading != 30 }
        // The button's size travels to its own.
        for _ in 0..<60 {
            guard styled.bounds.size != plain.bounds.size else { break }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
            host.frame()
            host.layOut()
        }

        XCTAssertEqual(Self.edge(of: styled), Self.edge(of: plain), "the platform's own box")
        XCTAssertEqual(styled.configuration?.contentInsets, plain.configuration?.contentInsets, "the platform's room")
        XCTAssertEqual(styled.bounds.size, plain.bounds.size)
    }

    /// A role draws as UIKit draws it where the tree draws nothing of its own: the main action filled in the tint, a
    /// destructive one's words in the system's red; a colour the tree states wins.
    func testARoleDrawsAsUIKitDrawsIt() throws {
        let host = UIKitRenderer.running {
            VStack {
                Button("Save").role(.primary)
                Button("Delete").role(.destructive)
                Button("Erase").role(.destructive).textColor(.blue)
                Button("Plain")
            }
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        defer { host.finish() }
        host.layOut()
        let buttons = host.views(UIKitButtonView.self)
        XCTAssertEqual(buttons.count, 4)

        XCTAssertNotEqual(Self.edge(of: buttons[0]).last, 0, "the main action's box filled")
        XCTAssertEqual(Self.edge(of: buttons[3]).last, 0, "a plain one's clear")
        XCTAssertEqual(buttons[1].configuration?.baseForegroundColor, .systemRed, "a destructive action's words")
        XCTAssertNotEqual(buttons[2].configuration?.baseForegroundColor, .systemRed, "the tree's colour wins")
    }

    /// The colour drawn just inside the button's leading edge, halfway down: its box, clear of its words.
    private static func edge(of button: UIView) -> [UInt8] {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(bounds: button.bounds, format: format).image { context in
            button.layer.render(in: context.cgContext)
        }
        guard let data = image.cgImage?.dataProvider?.data, let bytes = CFDataGetBytePtr(data),
            let cgImage = image.cgImage else { return [] }
        let (x, y) = (6, cgImage.height / 2)
        let at = y * cgImage.bytesPerRow + x * cgImage.bitsPerPixel / 8
        return (0..<4).map { bytes[at + $0] }
    }
}

/// A button wearing the sheet's style, or the platform's own look where `platform` says, and one never styled.
private struct StyledButtons: View {
    @Binding var platform: Bool
    @Environment(\.application) private var application

    var body: some View {
        let application = self.application
        return VStack {
            Button("Save").style(platform ? .platform : nil)
            Button("Save").style(.platform)
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
        .onCreated {
            application.styles = StyleSheet {
                Style<Button>()
                    .textColor(.white)
                    .background(.red)
                    .lineWidth(0)
                    .shape(.capsule)
                    .padding(horizontal: 30, vertical: 20)
                    .visualState(.disabled) { $0
                        .textColor(.gray)
                        .background(.blue)
                    }
            }
        }
    }
}
