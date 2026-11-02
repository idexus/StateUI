// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The pictures a host made: each found again while anything shows it, and the latest asked for kept besides, their
/// pixels within a budget - so a picture asked for again is the same picture, and a view handed it finds nothing
/// changed.
/// Design: docs/design/platforms/apple/pictures.md#the-pictures-made
@_spi(Host) @MainActor
public final class PictureCache<Image: AnyObject> {
    private let kept = NSCache<PictureCacheKey, Image>()
    private let shown = NSMapTable<PictureCacheKey, Image>.strongToWeakObjects()
    private let pixels: (Image) -> Int

    /// A cache keeping, of the pictures nothing shows, the latest asked for holding at most `budget` pixels together;
    /// `pixels` tells how many a picture holds.
    public init(budget: Int = PictureArithmetic.keptPixels, pixels: @escaping (Image) -> Int) {
        kept.totalCostLimit = budget
        self.pixels = pixels
    }

    /// The image made for `picture` - at a glyph's `height` where it stands as one - by `make` the first time it is
    /// asked for, and again only once nothing shows it and the budget let it go; nil where `make` makes none.
    public func image(_ picture: HostPicture, height: Double? = nil, make: () -> Image?) -> Image? {
        let key = PictureCacheKey(picture, height: height)
        if let found = kept.object(forKey: key) ?? shown.object(forKey: key) {
            kept.setObject(found, forKey: key, cost: pixels(found))
            return found
        }
        guard let made = make() else { return nil }
        kept.setObject(made, forKey: key, cost: pixels(made))
        shown.setObject(made, forKey: key)
        return made
    }

    /// Lets go of every picture kept that nothing shows, as the system does under memory pressure.
    public func letGoOfKept() {
        kept.removeAllObjects()
    }
}

/// A picture, at a glyph's height where it stands as one, as the key of the pictures made.
private final class PictureCacheKey: NSObject {
    let picture: HostPicture
    let height: Double?

    init(_ picture: HostPicture, height: Double?) {
        self.picture = picture
        self.height = height
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(picture)
        hasher.combine(height)
        return hasher.finalize()
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? PictureCacheKey else { return false }
        return other.picture == picture && other.height == height
    }
}
