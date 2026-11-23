// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// An Image: an `android.widget.ImageView` showing a picture - the application's, the platform's icon, or bytes -
/// cut to its bounds.
/// Design: docs/design/platforms/android/drawing.md#pictures
@MainActor
final class AndroidImageView: AndroidView {
    /// The picture, as the tree names it; nil for none.
    private(set) var picture: HostPicture?

    /// How the picture fills the view.
    private var aspect: ContentMode = .fit

    /// The picture's size in pixels, at the display's density; zero for none.
    private var pictureSize: (width: Int32, height: Int32) = (0, 0)

    /// The picture is held read at one pixel in `sample` across and down; 0 while none is held.
    private var sample: Int32 = 0
    private var held: AndroidPictures.Held?

    /// The thinning of a reading on its way to the view; 0 while none is.
    private var awaited: Int32 = 0

    init() {
        super.init { _ in Java.new(JavaAPI.imageView, JavaAPI.newImageView, .object(AndroidRenderer.context)) }
        Java.call(reference, JavaAPI.setCropToPadding, .bool(true))
    }

    /// Told the picture is another, which may be another size: the layouts around the view measure it again.
    var onSized: (@MainActor () -> Void)?

    /// Shows `picture`, filling its room as `aspect` says; it is read once the view's size is known.
    func apply(picture: HostPicture?, aspect: ContentMode) {
        if picture != self.picture {
            letGoOfPicture()
            self.picture = picture
            pictureSize = picture.flatMap(AndroidPictures.size(of:)) ?? (0, 0)
            Java.call(reference, JavaAPI.setImageBitmap, .object(nil))
            onSized?()
        }
        if aspect != self.aspect {
            self.aspect = aspect
            Java.call(reference, JavaAPI.requestLayout)
        }
        Java.call(reference, JavaAPI.setScaleType, .object(Self.scaleTypes[aspect]!.reference))
    }

    /// The picture's own size, within what each spec allows: the bitmap is read at the host's density,
    /// which Android's measure would scale a second time.
    override func measure(width: Int32, height: Int32) -> (width: Int32, height: Int32) {
        func resolved(_ spec: Int32, _ natural: Int32) -> Int32 {
            switch ViewConstants.mode(spec) {
            case ViewConstants.exactly: ViewConstants.size(spec)
            case ViewConstants.atMost: min(natural, ViewConstants.size(spec))
            default: natural
            }
        }

        let size = (width: resolved(width, pictureSize.width), height: resolved(height, pictureSize.height))
        // A StateUI layout measures a height it has not settled; only a size given whole is where it shows.
        if ViewConstants.mode(width) == ViewConstants.exactly, ViewConstants.mode(height) == ViewConstants.exactly {
            show(at: size)
        }
        return super.measure(
            width: ViewConstants.spec(ViewConstants.exactly, size.width),
            height: ViewConstants.spec(ViewConstants.exactly, size.height))
    }

    override func layout(_ place: Rect) {
        show(at: (AndroidPixels.size(place.width, density: density), AndroidPixels.size(place.height, density: density)))
        super.layout(place)
    }

    /// Holds the picture at the fewest pixels a view `shown` big needs: read at once the first time, then again only
    /// for more, beside the UI thread while the view shows what it holds - a size in motion never waits on it.
    /// Design: docs/design/platforms/android/drawing.md#pictures
    private func show(at shown: (width: Int32, height: Int32)) {
        guard let picture, pictureSize.width > 0, shown.width > 0, shown.height > 0 else { return }

        let needed = aspect == .center ? 1 : AndroidPictures.sample(picture, size: pictureSize, shown: shown)
        if sample == 0 {
            hold(AndroidPictures.take(picture, sample: needed), at: needed)
        } else if needed < (awaited == 0 ? sample : awaited) {
            awaited = needed
            if let taken = AndroidPictures.takeLater(picture, sample: needed, for: self) { hold(taken, at: needed) }
        }
    }

    /// A reading of the view's picture landed: shown where the view still waits for it.
    func landed(_ reading: AndroidPictures.Reading) {
        guard reading.picture == picture, reading.sample == awaited else { return }
        hold(AndroidPictures.take(reading.picture, sample: reading.sample), at: reading.sample)
    }

    /// Shows `taken`, read at one pixel in `sample`, and lets go of what the view held.
    private func hold(_ taken: AndroidPictures.Held?, at sample: Int32) {
        let bitmap = taken?.bitmap
        // Drawn at the host's density, as the picture was read and measured, not at the system's; an icon in the
        // theme's color.
        Java.frame {
            let drawable = bitmap.flatMap { bitmap in
                Java.callStaticObject(
                    JavaAPI.views, JavaAPI.pictureDrawable, .object(AndroidRenderer.context), .object(bitmap.reference))
            }
            if let drawable {
                Java.call(drawable, JavaAPI.setTargetDensity, .int(AndroidPictures.displayDensity))
            }
            Java.call(reference, JavaAPI.setImageDrawable, .object(drawable))
        }
        letGoOfPicture()
        (held, self.sample) = (taken, sample)
    }

    /// Lets go of the picture the view holds, and of any reading on its way to it.
    private func letGoOfPicture() {
        if let held { AndroidPictures.letGo(held) }
        (held, sample, awaited) = (nil, 0, 0)
    }

    override func detach() {
        super.detach()
        letGoOfPicture()
    }

    /// Android's scaling for each of StateUI's four.
    private static let scaleTypes: [ContentMode: JavaObject] = [
        .fit: Java.staticObject(JavaAPI.scaleType, "FIT_CENTER", "Landroid/widget/ImageView$ScaleType;"),
        .fill: Java.staticObject(JavaAPI.scaleType, "CENTER_CROP", "Landroid/widget/ImageView$ScaleType;"),
        .stretch: Java.staticObject(JavaAPI.scaleType, "FIT_XY", "Landroid/widget/ImageView$ScaleType;"),
        .center: Java.staticObject(JavaAPI.scaleType, "CENTER", "Landroid/widget/ImageView$ScaleType;"),
    ]
}
