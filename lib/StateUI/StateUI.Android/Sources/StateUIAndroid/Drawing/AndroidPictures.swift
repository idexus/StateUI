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

    /// A file's path in the assets, the density it was drawn at, and its size in pixels at the display's.
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
        let picture: HostPicture
        let sample: Int32
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

    /// The files in the APK's `images` assets.
    private static let files: Set<String> = Java.frame {
        let assets = Java.callObject(AndroidRenderer.context, JavaAPI.getAssets)!
        return Set(Java.texts(Java.callObject(assets, JavaAPI.listAssets, .object(Java.string("images")))))
    }

    /// The host's density, in pixels per inch: what every picture is read, measured and drawn at.
    static var displayDensity: Int32 { Int32((AndroidRenderer.density * 160).rounded()) }

    /// `picture`'s size in pixels at the display's density; nil where there is no such picture.
    ///
    /// An SVG - asked for by its own name, or by its `.png` name where no such file stands - is drawn three times over
    /// when the application is built, as `<name>@3x.png`; a file of the name itself, and bytes, are kept at one pixel
    /// a point. An icon stands at Android's icon size.
    static func size(of picture: HostPicture) -> (width: Int32, height: Int32)? {
        switch picture {
        case .file(let name): asset(named: name)?.size
        case .icon(let icon): icon.androidDrawable == nil ? nil : (iconPixels, iconPixels)
        case .bytes(let bytes): bounds(.bytes(bytes)).map { scaled($0, from: onePixelAPoint) }
        }
    }

    /// How thinly a picture `size` pixels big can be read for a view `shown` pixels big: one pixel in the answer
    /// across and down.
    static func sample(size: (width: Int32, height: Int32), shown: (width: Int32, height: Int32)) -> Int32 {
        guard size.width > 0, size.height > 0, shown.width > 0, shown.height > 0 else { return 1 }
        var sample: Int32 = 1
        while sample < thinnest, size.width / (sample * 2) >= shown.width, size.height / (sample * 2) >= shown.height {
            sample *= 2
        }
        return sample
    }

    /// `picture` read at one pixel in `sample`, held for one more view until it lets go; nil for no picture.
    static func take(_ picture: HostPicture, sample: Int32) -> JavaObject? {
        let reading = Reading(picture: picture, sample: sample)
        if let held = kept[reading] {
            kept[reading]?.holders = held.holders + 1
            return held.bitmap
        }
        guard let bitmap = decode(picture, sample: sample) else { return nil }

        kept[reading] = Kept(bitmap: bitmap, holders: 1)
        return bitmap
    }

    /// One view no longer shows `picture` read at `sample`; the last to let go lets the bitmap go.
    static func letGo(_ picture: HostPicture, sample: Int32) {
        let reading = Reading(picture: picture, sample: sample)
        guard let held = kept[reading] else { return }

        if held.holders > 1 { kept[reading]?.holders = held.holders - 1 } else { kept[reading] = nil }
    }

    /// `picture` whole, for a bar's or a tab's icon, which the host keeps for as long as it runs.
    static func bitmap(_ picture: HostPicture) -> JavaObject? {
        take(picture, sample: 1)
    }

    /// An icon's side in pixels at the display's density.
    private static var iconPixels: Int32 { Int32((iconSide * AndroidRenderer.density).rounded()) }

    /// `picture` read at one pixel in `sample`; nil where there is no such picture.
    private static func decode(_ picture: HostPicture, sample: Int32) -> JavaObject? {
        switch picture {
        case .file(let name): asset(named: name).flatMap { decode(.asset($0.path), density: $0.density, sample: sample) }
        case .bytes(let bytes): decode(.bytes(bytes), density: onePixelAPoint, sample: sample)
        case .icon(let icon): drawn(icon)
        }
    }

    /// `icon` drawn from the platform's drawable at Android's icon size, as a mask the view showing it colours.
    /// Design: docs/design/platforms/android/drawing.md#icons
    private static func drawn(_ icon: Icon) -> JavaObject? {
        guard let name = icon.androidDrawable else { return nil }

        return Java.frame {
            guard let mask = Java.callStaticObject(
                JavaAPI.views, JavaAPI.iconMask,
                .object(AndroidRenderer.context), .object(Java.string(name)), .int(iconPixels))
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
            bounds(.asset(found.path)).map { Asset(path: found.path, density: found.density, size: scaled($0, from: found.density)) }
        }
        if asset == nil { AndroidRenderer.log.error("no picture named \(name) in the application's images") }

        assets[name] = asset
        return asset
    }

    /// The pixels `encoded` holds, read from its header.
    private static func bounds(_ encoded: Encoded) -> (width: Int32, height: Int32)? {
        read(encoded, configure: { options in
            Java.set(options, JavaAPI.inJustDecodeBounds, true)
        }, finish: { options, _ in
            let size = (width: Java.int(options, JavaAPI.outWidth), height: Java.int(options, JavaAPI.outHeight))
            return size.width > 0 && size.height > 0 ? size : nil
        })
    }

    /// `encoded`, drawn at `density`, read at one pixel in `sample` and scaled to the display's density as it is
    /// read.
    private static func decode(_ encoded: Encoded, density: Int32, sample: Int32) -> JavaObject? {
        read(encoded, configure: { options in
            Java.set(options, JavaAPI.inSampleSize, sample)
            Java.set(options, JavaAPI.inDensity, density)
            Java.set(options, JavaAPI.inTargetDensity, displayDensity)
            Java.set(options, JavaAPI.inScaled, true)
        }, finish: { _, bitmap in
            guard let bitmap else { return nil }
            // The bitmap says the density a whole one would have, so it is drawn at the picture's own size.
            Java.call(bitmap, JavaAPI.setBitmapDensity, .int(max(1, displayDensity / sample)))
            return JavaObject(bitmap)
        })
    }

    /// Reads `encoded` with the options `configure` sets, and hands them and the bitmap - nil when only the bounds
    /// were asked for - to `finish`.
    private static func read<Result>(
        _ encoded: Encoded, configure: (jobject) -> Void, finish: (jobject, jobject?) -> Result?
    ) -> Result? {
        Java.frame {
            let options = Java.new(JavaAPI.bitmapOptions, JavaAPI.newBitmapOptions)
            return withExtendedLifetime(options) {
                configure(options.reference)
                switch encoded {
                case .asset(let path):
                    let assets = Java.callObject(AndroidRenderer.context, JavaAPI.getAssets)!
                    guard let stream = Java.callObject(assets, JavaAPI.openAsset, .object(Java.string(path))) else {
                        return nil
                    }

                    let bitmap = Java.callStaticObject(
                        JavaAPI.bitmapFactory, JavaAPI.decodeStream,
                        .object(stream), .object(nil), .object(options.reference))
                    Java.call(stream, JavaAPI.close)
                    return finish(options.reference, bitmap)
                case .bytes(let bytes):
                    let bitmap = Java.callStaticObject(
                        JavaAPI.bitmapFactory, JavaAPI.decodeByteArray,
                        .object(Java.bytes(bytes)), .int(0), .int(Int32(bytes.count)), .object(options.reference))
                    return finish(options.reference, bitmap)
                }
            }
        }
    }

    /// `size` pixels drawn at `density` pixels per inch, at the display's, rounded as Android rounds them.
    private static func scaled(_ size: (width: Int32, height: Int32), from density: Int32) -> (width: Int32, height: Int32) {
        let scale = Double(displayDensity) / Double(density)
        return (Int32((Double(size.width) * scale).rounded()), Int32((Double(size.height) * scale).rounded()))
    }
}
