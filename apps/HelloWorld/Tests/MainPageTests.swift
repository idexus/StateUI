import StateUI
import StateUITesting
import XCTest
@testable import HelloWorldUI

/// The opening page used as its user uses it, in a test's window: the button counts its clicks.
@MainActor
final class MainPageTests: XCTestCase {
    func testTheButtonCountsItsClicks() async throws {
        let window = try await TestWindow(motion: .none) { MainPage() }
        let button = try window.element("main.click")
        XCTAssertEqual(try button.value(TextElementContract.text), "Click me")

        try await button.perform(.activate)
        try await button.perform(.activate)

        XCTAssertEqual(try button.value(TextElementContract.text), "Clicked 2 times")
    }
}
