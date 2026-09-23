// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIAndroid

/// The application's pictures, read from its APK's `images` assets once each.
/// Design: docs/design/platforms/android/drawing.md#pictures
@MainActor
enum AndroidPictures {
    /// The pixels per inch a picture drawn three times over is kept at, `DisplayMetrics.DENSITY_XXHIGH`.
    private static let threeTimes: Int32 = 480

    /// A picture kept as it was drawn, at one pixel a point.
    private static let once: Int32 = 160

    /// The bitmaps read, by file name; nil for a name with no picture.
    private static var kept: [String: JavaObject?] = [:]

    /// The files in the APK's `images` assets.
    private static let files: Set<String> = Java.frame {
        let assets = Java.callObject(AndroidRenderer.context, JavaAPI.getAssets)!
        return Set(Java.texts(Java.callObject(assets, JavaAPI.listAssets, .object(Java.string("images")))))
    }

    /// The bitmap for `name`, at the display's density; nil where the application has no such picture.
    ///
    /// An SVG, asked for by its `.png` name, is drawn three times over when the application is built,
    /// as `<name>@3x.png`; a file of the name itself is kept at one pixel a point.
    static func bitmap(named name: String) -> JavaObject? {
        if let bitmap = kept[name] { return bitmap }

        let base = name.hasSuffix(".png") ? String(name.dropLast(4)) : name
        let bitmap: JavaObject? =
            if files.contains("\(base)@3x.png") { decode("images/\(base)@3x.png", density: threeTimes) }
            else if files.contains(name) { decode("images/\(name)", density: once) }
            else { nil }
        if bitmap == nil { AndroidLog.error("no picture named \(name) in the application's images") }

        kept[name] = bitmap
        return bitmap
    }

    /// The asset at `path`, drawn at `density` pixels per inch, scaled to the display's as it is read.
    private static func decode(_ path: String, density: Int32) -> JavaObject? {
        Java.frame {
            let assets = Java.callObject(AndroidRenderer.context, JavaAPI.getAssets)!
            let stream = Java.callObject(assets, JavaAPI.openAsset, .object(Java.string(path)))
            guard let stream else { return nil }

            let options = Java.new(JavaAPI.bitmapOptions, JavaAPI.newBitmapOptions)
            Java.set(options.reference, JavaAPI.inDensity, density)
            Java.set(options.reference, JavaAPI.inTargetDensity, Int32((AndroidRenderer.density * 160).rounded()))
            Java.set(options.reference, JavaAPI.inScaled, true)
            let bitmap = withExtendedLifetime(options) {
                Java.callStaticObject(
                    JavaAPI.bitmapFactory, JavaAPI.decodeStream,
                    .object(stream), .object(nil), .object(options.reference))
            }
            Java.call(stream, JavaAPI.close)
            return bitmap.map(JavaObject.init)
        }
    }
}
