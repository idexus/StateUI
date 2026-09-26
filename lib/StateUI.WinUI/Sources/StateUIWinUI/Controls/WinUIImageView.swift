// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// An Image: a WinUI `Image` showing a picture from the application's folder at its own size, filling the room
/// it is given as the aspect says.
/// Design: docs/design/platforms/winui/controls.md#pictures
@MainActor
final class WinUIImageView: WinUIView {
    /// The picture shown, by file name, and whether it was found.
    private(set) var file = ""
    private(set) var found = false

    /// How the picture fills its room.
    private var aspect = Aspect.fit

    /// The size an SVG declares, in DIPs; nil for a bitmap, whose size WinUI knows once it has read it.
    private var declared: LayoutSize?

    /// The size an SVG is drawn at, in DIPs; nil while it is not drawn.
    private var drawn: LayoutSize?

    init() {
        super.init { _ in stateui_winui_image_make() }
    }

    /// Shows the picture `source` names, filling its room as `aspect` says. Its layout is told itself: WinUI hears
    /// nothing from a picture that asks it for no room.
    func apply(source: ImageSource?, aspect: Aspect) {
        file = source?.file ?? ""
        self.aspect = aspect
        var size = [0.0, 0.0]
        let files = PictureArithmetic.files(for: file)
        found = WinUIStrings.withCStrings(files) { names in
            stateui_winui_image_set(handle, names, Int32(files.count), aspect.rawValue, &size)
        }
        if !found { WinUIRenderer.log.error("no picture \(file) among the application's pictures") }
        declared = size[0] > 0 && size[1] > 0 ? LayoutSize(width: size[0], height: size[1]) : nil
        drawn = nil
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

    /// Draws an SVG at the size it shows at in `room`, in its own proportions, so WinUI fills the room from it;
    /// again only for more pixels, so a size in motion does not draw it every frame. A stretched SVG has given up
    /// its proportions, and WinUI draws it at the room's size.
    private func draw(in room: Rect) {
        guard let declared, aspect != .stretch, room.width > 0, room.height > 0 else { return }

        let across = room.width / declared.width, down = room.height / declared.height
        let scale = switch aspect {
        case .fit: min(across, down)
        case .fill, .stretch: max(across, down)
        case .center: 1.0
        }
        let size = LayoutSize(width: declared.width * scale, height: declared.height * scale)
        if let drawn, drawn.width >= size.width, drawn.height >= size.height { return }

        drawn = size
        stateui_winui_image_draw(handle, size.width, size.height)
    }
}
