// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// The pictures views show - the application's files from its APK's `images` assets, the platform's icons, and
/// pictures given as bytes - read at the pixels the views showing them need, and kept while one does.
/// Design: docs/design/platforms/android/drawing.md#pictures
@MainActor
enum AndroidPictures {
    /// The pixels per inch of one pixel a point, `DisplayMetrics.DENSITY_DEFAULT`: a picture of more pixels a point
    /// is kept at as many times it.
    private static let onePixelAPoint: Int32 = 160

    /// The most a picture is thinned: one pixel in 16 across and down.
    private static let thinnest: Int32 = 16

    /// An icon's side, in points: Android's icon size.
    private static let iconSide = 24.0

    /// A file's path in the assets, the density it was drawn at, and its own size in pixels.
    private struct Asset {
        let path: String
        let density: Int32
        let pixels: (width: Int32, height: Int32)
    }

    /// A bitmap read, and how many views show it.
    private struct Kept {
        let bitmap: JavaObject
        var holders: Int
    }

    /// A picture read at one pixel in `sample` across and down, scaled to the display's density then.
    struct Reading: Hashable {
        let picture: HostPicture
        let sample: Int32
        let density: Int32
    }

    /// A picture a view holds: its bitmap, and the reading the view lets go of.
    struct Held {
        let reading: Reading
        let bitmap: JavaObject
    }

    /// Where a picture's encoded pixels are read from: a file in the assets, or the bytes themselves.
    private enum Encoded {
        case asset(String)
        case bytes([UInt8])
    }

    /// The files found, by name; nil for a name with no file.
    private static var assets: [String: Asset?] = [:]

    /// The bitmaps views show.
    private static var kept: [Reading: Kept] = [:]

    /// How many bitmaps are kept.
    static var keptCount: Int { kept.count }

    /// A view waiting for a reading, held weakly: one that left takes nothing.
    private struct Waiting {
        weak var view: AndroidImageView?
    }

    /// The readings on their way beside the UI thread, by ticket, and the views waiting for each.
    private static var onTheirWay: [Int64: Reading] = [:]
    private static var waiting: [Reading: [Waiting]] = [:]
    private static var lastTicket: Int64 = 0

    /// How many readings are on their way.
    static var readingsOnTheirWay: Int { onTheirWay.count }

    /// The files in the APK's `images` assets.
    private static let files: Set<String> = Java.frame {
        let assets = Java.callObject(AndroidRenderer.context, JavaAPI.getAssets)!
        return Set(Java.texts(Java.callObject(assets, JavaAPI.listAssets, .object(Java.string("images")))))
    }

    /// The host's density, in pixels per inch: what every picture is read, measured and drawn at.
    static var displayDensity: Int32 { AndroidPixels.distance(160, density: AndroidRenderer.density) }

    /// `picture`'s size in pixels at the display's density; nil where there is no such picture.
    ///
    /// An SVG - asked for by its own name, or by its `.png` name where no such file stands - is drawn three times over
    /// when the application is built, as `<name>@3x.png`; a file of the name itself, and bytes, are kept at one pixel
    /// a point. An icon stands at Android's icon size.
    static func size(of picture: HostPicture) -> (width: Int32, height: Int32)? {
        switch picture {
        case .file(let name): asset(named: name).map { scaled($0.pixels, from: $0.density) }
        case .icon: (iconPixels, iconPixels)
        case .bytes(let bytes): bounds(.bytes(bytes)).map { scaled($0, from: onePixelAPoint) }
        }
    }

    /// How thinly `picture`, `size` pixels big at the display's density, can be read for a view `shown` pixels big:
    /// one pixel in the answer across and down, while the picture's own pixels read still cover the view - a reading
    /// thins them before it scales them to the display's density.
    static func sample(
        _ picture: HostPicture, size: (width: Int32, height: Int32), shown: (width: Int32, height: Int32)
    ) -> Int32 {
        let ratio = Double(density(of: picture)) / Double(displayDensity)
        let own = (
            width: AndroidPixels.size(Double(size.width) * ratio, rounding: .towardZero),
            height: AndroidPixels.size(Double(size.height) * ratio, rounding: .towardZero))
        guard own.width > 0, own.height > 0, shown.width > 0, shown.height > 0 else { return 1 }
        var sample: Int32 = 1
        while sample < thinnest, own.width / (sample * 2) >= shown.width, own.height / (sample * 2) >= shown.height {
            sample *= 2
        }
        return sample
    }

    /// The density `picture` is drawn at, in pixels per inch: a file's, bytes' one pixel a point, an icon's the
    /// display's.
    private static func density(of picture: HostPicture) -> Int32 {
        switch picture {
        case .file(let name): asset(named: name)?.density ?? displayDensity
        case .bytes: onePixelAPoint
        case .icon: displayDensity
        }
    }

    /// `picture` read at one pixel in `sample` at the display's density now, held for one more view until it lets
    /// go; nil for no picture.
    static func take(_ picture: HostPicture, sample: Int32) -> Held? {
        let reading = Reading(picture: picture, sample: sample, density: displayDensity)
        if let held = kept[reading] {
            kept[reading]?.holders = held.holders + 1
            return Held(reading: reading, bitmap: held.bitmap)
        }
        guard let bitmap = decode(picture, sample: sample) else { return nil }

        kept[reading] = Kept(bitmap: bitmap, holders: 1)
        return Held(reading: reading, bitmap: bitmap)
    }

    /// `picture` read at one pixel in `sample` for `view`: held at once where it is kept or drawn, else read
    /// beside the UI thread and told to `view` as it lands - nil until then.
    /// Design: docs/design/platforms/android/drawing.md#pictures
    static func takeLater(_ picture: HostPicture, sample: Int32, for view: AndroidImageView) -> Held? {
        let reading = Reading(picture: picture, sample: sample, density: displayDensity)
        guard kept[reading] == nil, let found = encoded(picture) else { return take(picture, sample: sample) }

        if waiting[reading] == nil {
            lastTicket += 1
            onTheirWay[lastTicket] = reading
            read(found.encoded, density: found.density, sample: sample, later: lastTicket)
        }
        waiting[reading, default: []].append(Waiting(view: view))
        return nil
    }

    /// The reading under `ticket` landed, its bitmap nil where none was read: each view still waiting for it takes
    /// it, and one no view takes is let go.
    static func landed(ticket: Int64, bitmap: JavaObject?) {
        guard let reading = onTheirWay.removeValue(forKey: ticket) else { return }

        let views = waiting.removeValue(forKey: reading) ?? []
        guard let bitmap, reading.density == displayDensity else { return }

        if kept[reading] == nil { kept[reading] = Kept(bitmap: bitmap, holders: 0) }
        for view in views.compactMap(\.view) { view.landed(reading) }
        if kept[reading]?.holders == 0 { kept[reading] = nil }
    }

    /// One view no longer shows the picture it took; the last to let go of a reading lets its bitmap go.
    static func letGo(_ held: Held) {
        guard let kept = kept[held.reading] else { return }

        if kept.holders > 1 { self.kept[held.reading]?.holders = kept.holders - 1 } else { self.kept[held.reading] = nil }
    }

    /// `picture` whole, for a bar's or a tab's icon, which the host keeps for as long as it runs.
    static func bitmap(_ picture: HostPicture) -> JavaObject? {
        take(picture, sample: 1)?.bitmap
    }

    /// An icon's side in pixels at the display's density.
    private static var iconPixels: Int32 { AndroidPixels.size(iconSide, density: AndroidRenderer.density) }

    /// `picture` read at one pixel in `sample`; nil where there is no such picture.
    private static func decode(_ picture: HostPicture, sample: Int32) -> JavaObject? {
        if case .icon(let icon) = picture { return drawn(icon) }
        return encoded(picture).flatMap { read($0.encoded, density: $0.density, sample: sample) }
    }

    /// Where `picture`'s encoded pixels are, and the density it is drawn at; nil for an icon, which is drawn, and
    /// for no such file.
    private static func encoded(_ picture: HostPicture) -> (encoded: Encoded, density: Int32)? {
        switch picture {
        case .file(let name): asset(named: name).map { (.asset($0.path), $0.density) }
        case .bytes(let bytes): (.bytes(bytes), onePixelAPoint)
        case .icon: nil
        }
    }

    /// `icon` drawn from its drawable at Android's icon size, as a mask the view showing it colors.
    /// Design: docs/design/platforms/android/drawing.md#icons
    private static func drawn(_ icon: Icon) -> JavaObject? {
        Java.frame {
            guard let mask = Java.callStaticObject(
                JavaAPI.views, JavaAPI.iconMask,
                .object(AndroidRenderer.context), .object(Java.string(icon.androidDrawable)), .int(iconPixels))
            else { return nil }

            Java.call(mask, JavaAPI.setBitmapDensity, .int(displayDensity))
            return JavaObject(mask)
        }
    }

    /// The asset `name` stands for, its size read without its pixels.
    private static func asset(named name: String) -> Asset? {
        if let asset = assets[name] { return asset }

        // The name's own file, else its drawing (`PictureArithmetic.drawnFiles`).
        let found: (path: String, density: Int32)? = PictureArithmetic.drawnFiles(for: name).lazy.compactMap { drawn in
            files.contains(drawn.file) ? ("images/\(drawn.file)", Int32(drawn.scale) * onePixelAPoint) : nil
        }.first
        let asset = found.flatMap { found in
            bounds(.asset(found.path)).map { Asset(path: found.path, density: found.density, pixels: $0) }
        }
        if asset == nil { AndroidRenderer.log.error("no picture named \(name) in the application's images") }

        assets[name] = asset
        return asset
    }

    /// The pixels `encoded` holds, read from its header.
    private static func bounds(_ encoded: Encoded) -> (width: Int32, height: Int32)? {
        Java.frame {
            let from = source(encoded)
            guard let size = Java.callStaticObject(
                JavaAPI.pictures, JavaAPI.pictureSize, .object(from.assets), .object(from.path), .object(from.bytes))
            else { return nil }

            let pixels = Java.intsOf(size)
            return (pixels[0], pixels[1])
        }
    }

    /// `encoded`, drawn at `density`, read at one pixel in `sample` and scaled to the display's density as it is
    /// read.
    private static func read(_ encoded: Encoded, density: Int32, sample: Int32) -> JavaObject? {
        Java.frame {
            let from = source(encoded)
            return Java.callStaticObject(
                JavaAPI.pictures, JavaAPI.readPicture, .object(from.assets), .object(from.path), .object(from.bytes),
                .int(sample), .int(density), .int(displayDensity)
            ).map { JavaObject($0) }
        }
    }

    /// The same reading beside the UI thread, landing under `ticket`.
    private static func read(_ encoded: Encoded, density: Int32, sample: Int32, later ticket: Int64) {
        Java.frame {
            let from = source(encoded)
            Java.callStatic(
                JavaAPI.pictures, JavaAPI.readPictureLater, .long(ticket), .object(from.assets), .object(from.path),
                .object(from.bytes), .int(sample), .int(density), .int(displayDensity))
        }
    }

    /// `encoded` as `StateUIPictures` reads it: the assets, and a file's path or the bytes.
    private static func source(_ encoded: Encoded) -> (assets: jobject?, path: jstring?, bytes: jbyteArray?) {
        let assets = Java.callObject(AndroidRenderer.context, JavaAPI.getAssets)
        switch encoded {
        case .asset(let path): return (assets, Java.string(path), nil)
        case .bytes(let bytes): return (assets, nil, Java.bytes(bytes))
        }
    }

    /// `size` pixels drawn at `density` pixels per inch, at the display's, rounded as Android rounds them.
    private static func scaled(_ size: (width: Int32, height: Int32), from density: Int32) -> (width: Int32, height: Int32) {
        let scale = Double(displayDensity) / Double(density)
        return (AndroidPixels.size(Double(size.width) * scale), AndroidPixels.size(Double(size.height) * scale))
    }
}
