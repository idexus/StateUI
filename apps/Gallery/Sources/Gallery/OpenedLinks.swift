import StateUI

/// The links the application was asked to open, newest last - kept by the
/// galleries' scene, which hears them. See `GalleryScene`.
@MainActor
final class OpenedLinks {
    @State var addresses: [String] = []
}

// listing: OpenedLinks
/// What a gallery link names: `stateui-gallery://swatch/3` - or, on the Web,
/// the page's address ending `#swatch/3` - is swatch 3's window.
enum GalleryLink {
    /// The swatch a link names; nil for a link of anything else.
    static func swatch(in address: String) -> Int? {
        guard let named = address.split(separator: "swatch/").last, named.count < address.count else { return nil }
        return Int(named.prefix { $0.isNumber })
    }

    /// The link to swatch `number`: the Gallery's own scheme, or a fragment of the page on the Web.
    static func swatch(_ number: Int) -> String {
        #if WEB
        "#swatch/\(number)"
        #else
        "stateui-gallery://swatch/\(number)"
        #endif
    }
}
// listing: end
