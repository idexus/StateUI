// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI
import CStateUIAndroid

/// An Image: an `android.widget.ImageView` showing a picture of the application's, cut to its bounds.
/// Design: docs/design/platforms/android/drawing.md#pictures
@MainActor
final class AndroidImageView: AndroidView {
    /// The picture's file, as the tree names it; empty for none.
    private(set) var file = ""

    /// How the picture fills the view.
    private var aspect: Aspect = .fit

    /// The picture's size in pixels, at the display's density; zero for none.
    private var pictureSize: (width: Int32, height: Int32) = (0, 0)

    /// The picture is held read at one pixel in `sample` across and down; 0 while none is held.
    private var sample: Int32 = 0

    init() {
        super.init { _ in Java.new(JavaAPI.imageView, JavaAPI.newImageView, .object(AndroidRenderer.context)) }
        Java.call(reference, JavaAPI.setCropToPadding, .bool(true))
    }

    /// Shows the picture `source` names, filling its room as `aspect` says; it is read once the view's
    /// size is known.
    func apply(source: ImageSource?, aspect: Aspect) {
        let file = source?.file ?? ""
        if file != self.file {
            letGoOfPicture()
            self.file = file
            pictureSize = file.isEmpty ? (0, 0) : AndroidPictures.size(named: file) ?? (0, 0)
            Java.call(reference, JavaAPI.setImageBitmap, .object(nil))
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
        show(at: (pixels(place.width), pixels(place.height)))
        super.layout(place)
    }

    /// Holds the picture at the fewest pixels a view `shown` big needs, reading it again only for more:
    /// a size in motion does not read it every frame.
    /// Design: docs/design/platforms/android/drawing.md#pictures
    private func show(at shown: (width: Int32, height: Int32)) {
        guard !file.isEmpty, pictureSize.width > 0, shown.width > 0, shown.height > 0 else { return }

        let needed = aspect == .center ? 1 : AndroidPictures.sample(named: file, shown: shown)
        guard sample == 0 || needed < sample else { return }

        let bitmap = AndroidPictures.take(named: file, sample: needed)
        Java.call(reference, JavaAPI.setImageBitmap, .object(bitmap?.reference))
        letGoOfPicture()
        sample = needed
    }

    /// Lets go of the picture the view holds.
    private func letGoOfPicture() {
        guard sample != 0 else { return }

        AndroidPictures.letGo(named: file, sample: sample)
        sample = 0
    }

    override func detach() {
        super.detach()
        letGoOfPicture()
    }

    /// Android's scaling for each of StateUI's four.
    private static let scaleTypes: [Aspect: JavaObject] = [
        .fit: Java.staticObject(JavaAPI.scaleType, "FIT_CENTER", "Landroid/widget/ImageView$ScaleType;"),
        .fill: Java.staticObject(JavaAPI.scaleType, "CENTER_CROP", "Landroid/widget/ImageView$ScaleType;"),
        .stretch: Java.staticObject(JavaAPI.scaleType, "FIT_XY", "Landroid/widget/ImageView$ScaleType;"),
        .center: Java.staticObject(JavaAPI.scaleType, "CENTER", "Landroid/widget/ImageView$ScaleType;"),
    ]
}
