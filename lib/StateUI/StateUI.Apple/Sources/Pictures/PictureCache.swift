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
    /// A picture kept besides those shown: the pixels it holds, and when it was last asked for.
    private struct Kept {
        let image: Image
        let pixels: Int
        var asked: Int
    }

    private var kept: [PictureCacheKey: Kept] = [:]
    private var keptPixels = 0
    private var asked = 0
    private let budget: Int
    private let shown = NSMapTable<PictureCacheKey, Image>.strongToWeakObjects()
    private let pixels: (Image) -> Int
    private var memoryPressure: DispatchSourceMemoryPressure?

    /// A cache keeping, of the pictures nothing shows, the latest asked for holding at most `budget` pixels together;
    /// `pixels` tells how many a picture holds. It lets go of them only as its budget says, or as it is told.
    public init(budget: Int = PictureArithmetic.keptPixels, pixels: @escaping (Image) -> Int) {
        self.budget = budget
        self.pixels = pixels
    }

    /// The image made for `picture` - at a glyph's `height` where it stands as one - by `make` the first time it is
    /// asked for, and again only once nothing shows it and the budget let it go; nil where `make` makes none.
    public func image(_ picture: HostPicture, height: Double? = nil, make: () -> Image?) -> Image? {
        let key = PictureCacheKey(picture, height: height)
        asked += 1
        if let found = kept[key] {
            kept[key]?.asked = asked
            return found.image
        }
        if let found = shown.object(forKey: key) {
            keep(found, as: key)
            return found
        }
        guard let made = make() else { return nil }
        keep(made, as: key)
        shown.setObject(made, forKey: key)
        return made
    }

    /// Lets go of every picture kept that nothing shows.
    public func letGoOfKept() {
        kept.removeAll()
        keptPixels = 0
    }

    /// From now on lets go of every picture kept that nothing shows whenever the system says memory runs short.
    public func letGoOfKeptWhenMemoryRunsShort() {
        guard memoryPressure == nil else { return }
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.letGoOfKept() } }
        source.activate()
        memoryPressure = source
    }

    /// Whether it hears the system say memory runs short.
    public var hearsMemoryPressure: Bool { memoryPressure != nil }

    /// Keeps `image`, letting go of the ones asked for longest ago until the kept hold no more than the budget; one
    /// holding more than the whole budget is not kept.
    /// Design: docs/design/platforms/apple/pictures.md#the-pictures-made
    private func keep(_ image: Image, as key: PictureCacheKey) {
        let cost = pixels(image)
        guard cost <= budget else { return }
        kept[key] = Kept(image: image, pixels: cost, asked: asked)
        keptPixels += cost
        while keptPixels > budget, let oldest = kept.min(by: { $0.value.asked < $1.value.asked }) {
            keptPixels -= oldest.value.pixels
            kept[oldest.key] = nil
        }
    }

    isolated deinit {
        memoryPressure?.cancel()
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
