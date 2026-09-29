import XCTest
@testable import HelloWorldUI

/// The application's own logic, tested as plain Swift: what the page's button
/// says as it is clicked.
final class MainPageTests: XCTestCase {
    func testTheButtonCountsItsClicks() {
        XCTAssertEqual(MainPage.caption(clicks: 0), "Click me")
        XCTAssertEqual(MainPage.caption(clicks: 1), "Clicked 1 time")
        XCTAssertEqual(MainPage.caption(clicks: 2), "Clicked 2 times")
    }
}
