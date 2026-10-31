@testable import GalleryUI
import XCTest

/// What a gallery link names: the sample after `sample/`, in the Gallery's own scheme or a page's fragment.
final class GalleryLinkTests: XCTestCase {
    func testALinkNamesItsSample() {
        XCTAssertEqual(GalleryLink.sample(in: "stateui-gallery://sample/tap"), "tap")
        XCTAssertEqual(GalleryLink.sample(in: "http://localhost:8460/#sample/windowPhase"), "windowPhase")
        XCTAssertNil(GalleryLink.sample(in: "stateui-gallery://swatch/3"), "a link of anything else")
        XCTAssertNil(GalleryLink.sample(in: "stateui-gallery://sample/"), "no sample")
    }

    /// A link the window is given shows the sample it names over its group, and is noted; one naming no sample is
    /// only noted.
    @MainActor
    func testAWindowFollowsALinkToItsSample() {
        let nav = Navigation()
        let catalog = Catalog(nav: nav, style: SessionStyle(), bar: WindowBarState(), log: WindowLog())

        nav.follow(link: "stateui-gallery://sample/tap", in: catalog)
        XCTAssertEqual(nav.path, [.group("gestures"), .sample("tap")])

        nav.follow(link: "stateui-gallery://sample/nothing", in: catalog)
        XCTAssertEqual(nav.path, [.group("gestures"), .sample("tap")], "a link naming no sample moves nothing")
        XCTAssertEqual(nav.links, ["stateui-gallery://sample/tap", "stateui-gallery://sample/nothing"])
    }
}
