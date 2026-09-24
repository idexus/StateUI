// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIAndroid

/// The application's pictures, read from its APK's `images` assets at the pixels the views showing
/// them need, and kept while one does.
/// Design: docs/design/platforms/android/drawing.md#pictures
@MainActor
enum AndroidPictures {
    /// The pixels per inch a picture drawn three times over is kept at, `DisplayMetrics.DENSITY_XXHIGH`.
    private static let threeTimes: Int32 = 480

    /// A picture kept as it was drawn, at one pixel a point.
    private static let once: Int32 = 160

    /// The most a picture is thinned: one pixel in 16 across and down.
    private static let thinnest: Int32 = 16

    /// A picture's file, the density it was drawn at, and its size in pixels at the display's.
    private struct Asset {
        let path: String
        let density: Int32
        let size: (width: Int32, height: Int32)
    }

    /// A bitmap read, and how many views show it.
    private struct Kept {
        let bitmap: JavaObject
        var holders: Int
    }

    /// A picture read at one pixel in `sample` across and down.
    private struct Reading: Hashable {
        let name: String
        let sample: Int32
    }

    /// The pictures found, by name; nil for a name with no picture.
    private static var assets: [String: Asset?] = [:]

    /// The bitmaps views show.
    private static var kept: [Reading: Kept] = [:]

    /// How many bitmaps are kept.
    static var keptCount: Int { kept.count }

    /// The files in the APK's `images` assets.
    private static let files: Set<String> = Java.frame {
        let assets = Java.callObject(AndroidRenderer.context, JavaAPI.getAssets)!
        return Set(Java.texts(Java.callObject(assets, JavaAPI.listAssets, .object(Java.string("images")))))
    }

    /// The display's pixels per inch.
    private static var displayDensity: Int32 { Int32((AndroidRenderer.density * 160).rounded()) }

    /// `name`'s size in pixels at the display's density; nil where the application has no such picture.
    ///
    /// An SVG, asked for by its `.png` name, is drawn three times over when the application is built,
    /// as `<name>@3x.png`; a file of the name itself is kept at one pixel a point.
    static func size(named name: String) -> (width: Int32, height: Int32)? {
        asset(named: name)?.size
    }

    /// How thinly `name` can be read for a view `shown` pixels big: one pixel in the answer across and down.
    static func sample(named name: String, shown: (width: Int32, height: Int32)) -> Int32 {
        guard let size = asset(named: name)?.size, shown.width > 0, shown.height > 0 else { return 1 }
        var sample: Int32 = 1
        while sample < thinnest, size.width / (sample * 2) >= shown.width, size.height / (sample * 2) >= shown.height {
            sample *= 2
        }
        return sample
    }

    /// `name` read at one pixel in `sample`, held for one more view until it lets go; nil for no picture.
    static func take(named name: String, sample: Int32) -> JavaObject? {
        let reading = Reading(name: name, sample: sample)
        if let held = kept[reading] {
            kept[reading]?.holders = held.holders + 1
            return held.bitmap
        }
        guard let asset = asset(named: name), let bitmap = decode(asset, sample: sample) else { return nil }

        kept[reading] = Kept(bitmap: bitmap, holders: 1)
        return bitmap
    }

    /// One view no longer shows `name` read at `sample`; the last to let go lets the bitmap go.
    static func letGo(named name: String, sample: Int32) {
        let reading = Reading(name: name, sample: sample)
        guard let held = kept[reading] else { return }

        if held.holders > 1 { kept[reading]?.holders = held.holders - 1 } else { kept[reading] = nil }
    }

    /// `name` whole, for a bar's or a tab's icon, which the host keeps for as long as it runs.
    static func bitmap(named name: String) -> JavaObject? {
        take(named: name, sample: 1)
    }

    /// The asset `name` stands for, its size read without its pixels.
    private static func asset(named name: String) -> Asset? {
        if let asset = assets[name] { return asset }

        let base = name.hasSuffix(".png") ? String(name.dropLast(4)) : name
        let found: (path: String, density: Int32)? =
            if files.contains("\(base)@3x.png") { ("images/\(base)@3x.png", threeTimes) }
            else if files.contains(name) { ("images/\(name)", once) }
            else { nil }
        let asset = found.flatMap { found in
            bounds(found.path).map { Asset(path: found.path, density: found.density, size: scaled($0, from: found.density)) }
        }
        if asset == nil { AndroidLog.error("no picture named \(name) in the application's images") }

        assets[name] = asset
        return asset
    }

    /// The pixels the asset at `path` holds, read from its header.
    private static func bounds(_ path: String) -> (width: Int32, height: Int32)? {
        read(path, configure: { options in
            Java.set(options, JavaAPI.inJustDecodeBounds, true)
        }, finish: { options, _ in
            let size = (width: Java.int(options, JavaAPI.outWidth), height: Java.int(options, JavaAPI.outHeight))
            return size.width > 0 && size.height > 0 ? size : nil
        })
    }

    /// The asset read at one pixel in `sample`, scaled to the display's density as it is read.
    private static func decode(_ asset: Asset, sample: Int32) -> JavaObject? {
        read(asset.path, configure: { options in
            Java.set(options, JavaAPI.inSampleSize, sample)
            Java.set(options, JavaAPI.inDensity, asset.density)
            Java.set(options, JavaAPI.inTargetDensity, displayDensity)
            Java.set(options, JavaAPI.inScaled, true)
        }, finish: { _, bitmap in
            guard let bitmap else { return nil }
            // The bitmap says the density a whole one would have, so it is drawn at the picture's own size.
            Java.call(bitmap, JavaAPI.setBitmapDensity, .int(max(1, displayDensity / sample)))
            return JavaObject(bitmap)
        })
    }

    /// Reads the asset at `path` with the options `configure` sets, and hands them and the bitmap - nil
    /// when only the bounds were asked for - to `finish`.
    private static func read<Result>(
        _ path: String, configure: (jobject) -> Void, finish: (jobject, jobject?) -> Result?
    ) -> Result? {
        Java.frame {
            let assets = Java.callObject(AndroidRenderer.context, JavaAPI.getAssets)!
            guard let stream = Java.callObject(assets, JavaAPI.openAsset, .object(Java.string(path))) else { return nil }

            let options = Java.new(JavaAPI.bitmapOptions, JavaAPI.newBitmapOptions)
            return withExtendedLifetime(options) {
                configure(options.reference)
                let bitmap = Java.callStaticObject(
                    JavaAPI.bitmapFactory, JavaAPI.decodeStream,
                    .object(stream), .object(nil), .object(options.reference))
                Java.call(stream, JavaAPI.close)
                return finish(options.reference, bitmap)
            }
        }
    }

    /// `size` pixels drawn at `density` pixels per inch, at the display's, rounded as Android rounds them.
    private static func scaled(_ size: (width: Int32, height: Int32), from density: Int32) -> (width: Int32, height: Int32) {
        let scale = Double(displayDensity) / Double(density)
        return (Int32((Double(size.width) * scale).rounded()), Int32((Double(size.height) * scale).rounded()))
    }
}
