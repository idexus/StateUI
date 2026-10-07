// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import StateUIConformance
import XCTest

final class WinUIButtonViewTests: XCTestCase {
    /// A button styled by the application wears its fill, its words' colour and its rounded corners; the corner
    /// outside the rounding shows nothing of it.
    func testAButtonWearsItsFillWordsAndCorners() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    Button("Go")
                        .background(Color("#512BD4"))
                        .textColor(Color("#FFFFFF"))
                        .shape(.roundedRectangle(10))
                        .padding(horizontal: 16, vertical: 11)
                        .width(120)
                        .height(40)
                        .horizontalAlignment(.start)
                }
            }
            let button = try XCTUnwrap(host.views(WinUIButtonView.self).first)

            XCTAssertEqual(button.pixels(at: [(60, 3), (0.5, 0.5)]), [0xFF51_2BD4, 0], "the fill, a corner cut")
        }
    }

    /// A fill and words' colour the tree changes after the button is drawn stand under the pointer too, the fill a
    /// little fainter: the template takes those states' brushes from the button's own resources as they are now.
    func testAColourChangedLaterStandsUnderThePointer() throws {
        try onUIThread {
            let blue = State(wrappedValue: false)
            let host = WinUIRenderer.running {
                VStack {
                    Button("Go")
                        .background(Color(blue.wrappedValue ? "#0000FF" : "#FF0000"))
                        .textColor(Color(blue.wrappedValue ? "#00FF00" : "#FFFF00"))
                        .lineWidth(0)
                        .width(120)
                        .height(40)
                        .horizontalAlignment(.start)
                }
            }
            let button = try XCTUnwrap(host.views(WinUIButtonView.self).first)
            host.settle { button.pixels(at: [(60, 3)]) == [0xFFFF_0000] }

            blue.wrappedValue = true
            host.settle { button.pixels(at: [(60, 3)]) == [0xFF00_00FF] }
            XCTAssertTrue(stateui_winui_go_to_state(button.handle, "PointerOver"))
            host.layOut()
            let fill = button.pixels(at: [(60, 3)])[0]
            XCTAssertNotEqual(fill, 0xFF00_00FF, "drawn fainter under the pointer")
            XCTAssertTrue(fill & 0xFF > 0 && (fill >> 16) & 0xFF == 0, "blue under the pointer: \(String(fill, radix: 16))")
        }
    }

    /// A button is named by its words, alone or beside a picture: its content is a text block, not the words.
    func testAButtonIsNamedByItsWords() {
        onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    Button("Go")
                    Button("Send").icon("test_wide.png").iconPosition(.trailing)
                }
            }
            let buttons = host.views(WinUIButtonView.self)
            XCTAssertEqual(buttons.map(\.automationWords.name), ["Go", "Send"])
        }
    }

    /// A picture beside a button's words stands at its own size - an SVG at the size it declares, which WinUI takes
    /// for thousands of pixels - so the button stays a button's size.
    func testAPictureBesideTheWordsStandsAtItsOwnSize() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack { Button("Go").icon("test_wide.png").horizontalAlignment(.start) }
            }
            let button = try XCTUnwrap(host.views(WinUIButtonView.self).first)
            host.settle { button.frame.width > 0 }
            XCTAssertLessThan(button.frame.width, 150, "\(button.frame)")
            XCTAssertLessThan(button.frame.height, 60, "\(button.frame)")
        }
    }

    /// A button placed lower than the picture beside its words shows its words whole: the picture stands no taller
    /// than the room the place leaves it. WinUI arranges a button at no less than it measured, and StateUI measures
    /// it with no bound on its height.
    func testAButtonLowerThanItsPictureShowsItsWordsWhole() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    Button("Go").icon("test_wide.png").fontSize(6).padding(horizontal: 4, vertical: 0).height(12).horizontalAlignment(.start)
                }
            }
            let button = try XCTUnwrap(host.views(WinUIButtonView.self).first)
            host.settle { (Double(Self.read(button, "captionBottom")) ?? 99) <= 12 }
            XCTAssertLessThanOrEqual(Double(Self.read(button, "captionBottom")) ?? 99, 12, "the words' bottom")
        }
    }

    /// A button's words spaced wider stand wider: the room between its letters reaches the words its template draws.
    func testAButtonsLettersSpacedWiderMakeItWider() {
        onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    Button("Spaced").horizontalAlignment(.start)
                    Button("Spaced").tracking(6).horizontalAlignment(.start)
                }
            }
            let buttons = host.views(WinUIButtonView.self)
            XCTAssertEqual(buttons.count, 2)
            let (plain, spaced) = (buttons[0].measure(width: nil, height: nil), buttons[1].measure(width: nil, height: nil))
            XCTAssertGreaterThanOrEqual(spaced.width - plain.width, 30, "six letters, each six wider")
        }
    }

    /// An oval button is a capsule at its size: its corners round by half its shorter side, however wide it is.
    func testAnOvalButtonRoundsItsCornersByHalfItsShorterSide() {
        onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    Button().shape(.ellipse).width(60).height(40).horizontalAlignment(.start)
                }
            }
            let button = host.views(WinUIButtonView.self)[0]
            host.settle { Self.read(button, "cornerRadius").hasPrefix("20") }
            XCTAssertTrue(Self.read(button, "cornerRadius").hasPrefix("20"), Self.read(button, "cornerRadius"))
        }
    }

    @MainActor private static func read(_ view: WinUIView, _ what: String) -> String {
        WinUIStrings.read { stateui_winui_read(view.handle, what, $0, $1) }
    }

    /// A picture alone fills its button as its aspect says - fitted whole, or covering it - and is cut at the
    /// button's edge: nothing of it stands beside the button.
    func testAPictureAloneFillsItsButtonAsItsAspectSays() throws {
        try onUIThread {
            for (aspect, drawn, empty) in [
                (ContentMode.fit, [(20.0, 20.0)], [(20.0, 5.0), (60.0, 20.0)]),
                (ContentMode.fill, [(20.0, 5.0), (20.0, 35.0), (2.0, 20.0)], [(60.0, 20.0)]),
            ] {
                let host = WinUIRenderer.running {
                    HStack {
                        Button(icon: "test_wide.png")
                            .contentMode(aspect)
                            .background(.transparent)
                            .lineWidth(0)
                            .padding(horizontal: 0, vertical: 0)
                            .width(40)
                            .height(40)
                        Text("").width(40).height(40)
                    }
                    .spacing(0)
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                let row = try XCTUnwrap(host.views(WinUIStackView.self).first)
                host.settle { row.pixels(at: drawn).allSatisfy { $0 == 0xFF33_6699 } }
                XCTAssertEqual(row.pixels(at: drawn), drawn.map { _ in 0xFF33_6699 }, "\(aspect): the picture")
                XCTAssertEqual(row.pixels(at: empty), empty.map { _ in 0 }, "\(aspect): nothing of it")
            }
        }
    }

    /// A button nothing styles is WinUI's own: the platform's fill, not the application's.
    func testAButtonNothingStylesIsWinUIsOwn() throws {
        try onUIThread {
            let host = WinUIRenderer.running { VStack { Button("Plain").width(120).height(40).horizontalAlignment(.start) } }
            let button = try XCTUnwrap(host.views(WinUIButtonView.self).first)

            XCTAssertNotEqual(button.pixels(at: [(60, 3)]), [0xFF51_2BD4])
            XCTAssertNotEqual(button.pixels(at: [(60, 3)]), [0], "WinUI fills its own button")
        }
    }
}
