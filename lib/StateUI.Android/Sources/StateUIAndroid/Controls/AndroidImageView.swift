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

    /// The picture's size in pixels, read at the display's density; zero for none.
    private var pictureSize: (width: Int32, height: Int32) = (0, 0)

    init() {
        super.init { _ in Java.new(JavaAPI.imageView, JavaAPI.newImageView, .object(AndroidRenderer.context)) }
        Java.call(reference, JavaAPI.setCropToPadding, .bool(true))
    }

    /// Shows the picture `source` names, filling its room as `aspect` says.
    func apply(source: ImageSource?, aspect: Aspect) {
        let file = source?.file ?? ""
        if file != self.file {
            self.file = file
            let bitmap = file.isEmpty ? nil : AndroidPictures.bitmap(named: file)
            Java.call(reference, JavaAPI.setImageBitmap, .object(bitmap?.reference))
            pictureSize = bitmap.map {
                (Java.callInt($0.reference, JavaAPI.bitmapWidth), Java.callInt($0.reference, JavaAPI.bitmapHeight))
            } ?? (0, 0)
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

        return super.measure(
            width: ViewConstants.spec(ViewConstants.exactly, resolved(width, pictureSize.width)),
            height: ViewConstants.spec(ViewConstants.exactly, resolved(height, pictureSize.height)))
    }

    /// Android's scaling for each of StateUI's four.
    private static let scaleTypes: [Aspect: JavaObject] = [
        .fit: Java.staticObject(JavaAPI.scaleType, "FIT_CENTER", "Landroid/widget/ImageView$ScaleType;"),
        .fill: Java.staticObject(JavaAPI.scaleType, "CENTER_CROP", "Landroid/widget/ImageView$ScaleType;"),
        .stretch: Java.staticObject(JavaAPI.scaleType, "FIT_XY", "Landroid/widget/ImageView$ScaleType;"),
        .center: Java.staticObject(JavaAPI.scaleType, "CENTER", "Landroid/widget/ImageView$ScaleType;"),
    ]
}
