import StateUI

// listing: GalleryLink
/// What a gallery link names: `stateui-gallery://sample/tap` - or, on the Web,
/// the page's address ending `#sample/tap` - is the Tap sample.
enum GalleryLink {
    /// The sample a link names; nil for a link of anything else.
    static func sample(in address: String) -> String? {
        let parts = address.split(separator: "/", omittingEmptySubsequences: false)
        guard let place = parts.lastIndex(where: { $0 == "sample" || $0.hasSuffix("#sample") }),
              place + 1 < parts.count
        else { return nil }
        let id = parts[place + 1].prefix { $0.isLetter || $0.isNumber }
        return id.isEmpty ? nil : String(id)
    }

    /// The link to the sample `id`: the Gallery's own scheme, or a fragment of the page on the Web.
    static func sample(_ id: String) -> String {
        #if WEB
        "#sample/\(id)"
        #else
        "stateui-gallery://sample/\(id)"
        #endif
    }
}
// listing: end
