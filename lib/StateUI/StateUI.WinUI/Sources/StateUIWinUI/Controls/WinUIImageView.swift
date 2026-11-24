// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// An Image: a WinUI `Image` showing a picture from the application's folder or bytes at its own size, or a
/// `FontIcon` showing an icon, filling the room it is given as the aspect says.
/// Design: docs/design/platforms/winui/controls.md#pictures
@MainActor
final class WinUIImageView: WinUIView {
    /// The picture shown, and whether it was found.
    private(set) var picture: HostPicture?
    private(set) var found = false

    /// How the picture fills its room.
    private var aspect = ContentMode.fit

    /// The size an SVG declares, in DIPs; nil for a bitmap, whose size WinUI knows once it has read it.
    private var declared: LayoutSize?

    /// The drawings of an SVG by their DIPs: the one shown and the one on its way.
    private var drawings = PictureDrawings()

    init() {
        super.init { _ in stateui_winui_image_make() }
    }

    /// Shows `picture`, filling its room as `aspect` says. Its layout is told itself: WinUI hears nothing from a
    /// picture that asks it for no room.
    func apply(picture: HostPicture?, aspect: ContentMode) {
        self.picture = picture
        self.aspect = aspect
        var size = [0.0, 0.0]
        let lines = WinUIPictures.lines(picture)
        found = WinUIStrings.withCStrings(lines) { names in
            stateui_winui_image_set(handle, names, Int32(lines.count), aspect.rawValue, &size)
        }
        if !found { WinUIRenderer.log.error("no picture \(picture?.identity ?? "") among the application's pictures") }
        declared = size[0] > 0 && size[1] > 0 ? LayoutSize(width: size[0], height: size[1]) : nil
        drawings = PictureDrawings()
        if let placed { draw(in: placed) }
        placingLayout?.invalidateMeasurements()
    }

    /// The picture's own size, whatever the room offered: an SVG's declared, a bitmap's once read. WinUI is asked
    /// for no room, so the picture is drawn in the place its layout gives it.
    /// Design: docs/design/platforms/winui/controls.md#pictures
    override func measure(width: Double?, height: Double?) -> LayoutSize {
        _ = super.measure(width: 0, height: 0)
        if let declared { return declared }
        var size = [0.0, 0.0]
        stateui_winui_image_size(handle, &size)
        return LayoutSize(width: size[0], height: size[1])
    }

    override func layout(_ place: Rect) {
        super.layout(place)
        draw(in: place)
    }

    /// Draws an SVG at the size it shows at in `room` - in its own proportions, or, stretched, at the room's - so
    /// WinUI fills the room from it; again only as it crosses a step of its pixels, so a size in motion does not
    /// draw it every frame (`PictureArithmetic.vectorPixels`, `PictureDrawings`). A later drawing is made under the
    /// one shown, which stays until it is: WinUI stands an image blank through each drawing it is given.
    /// Design: docs/design/platforms/winui/controls.md#pictures
    private func draw(in room: Rect) {
        guard let declared, room.width > 0, room.height > 0 else { return }

        let wanted = PictureArithmetic.vectorPixels(
            declared, in: LayoutSize(width: room.width, height: room.height), aspect: aspect, scale: 1)
        guard wanted.width > 0, wanted.height > 0, let size = drawings.asks(for: wanted) else { return }

        if stateui_winui_image_draw(handle, number, size.width, size.height) { _ = drawings.landed(size) }
    }

    /// The drawing asked at `size` was `made`, or cannot be: shown where it is still the one on its way.
    func drawn(_ size: LayoutSize, made: Bool) {
        guard made else { return drawings.lost(size) }
        if drawings.landed(size) { stateui_winui_image_take(handle) }
    }
}
