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

    /// Every sample's link names that sample, in the Gallery's own scheme and as a page's fragment - an id written
    /// with a hyphen whole - and what follows it, a query or a fragment, is no part of it.
    @MainActor
    func testEverySamplesLinkNamesIt() {
        let catalog = Catalog(nav: Navigation(), style: SessionStyle(), bar: WindowBarState(), log: WindowLog())
        let ids = catalog.groups.flatMap { $0.samples.map(\.id) }
        XCTAssertTrue(ids.contains("driven-reading"))
        for id in ids {
            XCTAssertEqual(GalleryLink.sample(in: "stateui-gallery://sample/\(id)"), id)
            XCTAssertEqual(GalleryLink.sample(in: "http://localhost:8460/#sample/\(id)"), id)
            XCTAssertEqual(GalleryLink.sample(in: "stateui-gallery://sample/\(id)?from=readme"), id)
            XCTAssertEqual(GalleryLink.sample(in: "stateui-gallery://sample/\(id)#top"), id)
        }
        let nav = Navigation()
        nav.follow(link: "stateui-gallery://sample/driven-reading", in: catalog)
        XCTAssertEqual(nav.path.last, .sample("driven-reading"))
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
