@testable import GalleryUI
import XCTest

/// What a gallery link names: the swatch after `swatch/`, in the Gallery's own scheme or a page's fragment.
final class GalleryLinkTests: XCTestCase {
    func testALinkNamesItsSwatch() {
        XCTAssertEqual(GalleryLink.swatch(in: "stateui-gallery://swatch/3"), 3)
        XCTAssertEqual(GalleryLink.swatch(in: "http://localhost:8460/#swatch/12"), 12)
        XCTAssertNil(GalleryLink.swatch(in: "stateui-gallery://sample/hold"), "a link of anything else")
        XCTAssertNil(GalleryLink.swatch(in: "stateui-gallery://swatch/"), "no number")
    }
}
