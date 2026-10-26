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
    /// destructive one's words in the system's red; a color the tree states wins.
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
        XCTAssertNotEqual(buttons[2].configuration?.baseForegroundColor, .systemRed, "the tree's color wins")
    }

    /// A BOX CHANGING ITS COLOR KEEPS ITS CORNERS: a capsule whose fill travels to another color - a button let go,
    /// lit no more - hands UIKit its radius with every look it is given. UIKit moves its own box from the last look
    /// it was given, as it takes a highlight off: a look given without the radius rounds the box anew.
    func testABoxChangingItsColorKeepsItsCorners() throws {
        let lit = State(wrappedValue: true)
        let host = UIKitRenderer.running { LitButton(lit: lit.projectedValue) }
        defer { host.finish() }
        host.layOut()
        let button = try XCTUnwrap(host.views(UIKitButtonView.self).first)
        host.settle { button.configuration?.background.cornerRadius ?? 0 > 0 }
        let whole = try XCTUnwrap(button.configuration?.background.cornerRadius)

        let given = GivenLooks()
        button.addObserver(given, forKeyPath: "configuration", options: [.new], context: nil)
        defer { button.removeObserver(given, forKeyPath: "configuration") }
        lit.wrappedValue = false
        for _ in 0..<30 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
            host.frame()
            host.layOut()
        }

        XCTAssertFalse(given.radii.isEmpty, "the color traveled")
        XCTAssertEqual(given.radii.filter { abs($0 - whole) > 0.01 }, [], "every look given with the capsule's radius")
    }

    /// `layer` and every layer under it.
    private static func layers(under layer: CALayer) -> [CALayer] {
        [layer] + (layer.sublayers ?? []).flatMap { layers(under: $0) }
    }

    /// The color drawn just inside the button's leading edge, halfway down: its box, clear of its words.
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

/// A capsule button lit or not by `lit`, its fill traveling between the two.
private struct LitButton: View {
    @Binding var lit: Bool

    var body: some View {
        Button("Lit")
            .shape(.capsule)
            .background(lit ? .red : .blue)
            .lineWidth(0)
            .padding(horizontal: 22, vertical: 10)
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
    }
}

/// The radius of every look a button is given, as UIKit hears its configuration set.
private final class GivenLooks: NSObject {
    var radii: [CGFloat] = []

    override func observeValue(
        forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard let look = change?[.newKey] as? NSObject,
              let radius = look.value(forKeyPath: "background.cornerRadius") as? CGFloat else { return }
        radii.append(radius)
    }
}
