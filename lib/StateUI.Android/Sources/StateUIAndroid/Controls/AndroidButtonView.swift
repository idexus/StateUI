// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// A Button: an `android.widget.Button` whose click reaches Swift through its `StateUIListener`.
@MainActor
final class AndroidButtonView: AndroidTextView {
    /// What the button does when it is clicked.
    var onClicked: (() -> Void)?

    /// What the button does as a finger takes hold of it.
    var onPressed: (() -> Void)?

    /// What the button does as the finger lets go, whether or not it clicked.
    var onReleased: (() -> Void)?

    /// What the button draws itself with: a fill, an outline and its corners, in points.
    private var look = Look()

    /// The icon, where it stands, how it fills the room, and the picture held for it.
    private var icon = Icon()

    /// Whether the button has words: without them its icon stands alone in the middle.
    private var hasWords = false

    /// What the icon was last shown as, so an unchanged one is not sent again.
    private var shownIcon: Icon.Shown?

    init() {
        super.init { _ in Java.new(JavaAPI.button, JavaAPI.newButton, .object(AndroidRenderer.context)) }
        Java.call(reference, JavaAPI.setAllCaps, .bool(false))
        setLeastSize(width: 0, height: 0)

        listen(JavaAPI.setOnClickListener, JavaAPI.setOnTouchListener)
    }

    /// The least pixels the button takes, in place of its theme's: a button is its words and its padding.
    /// Design: docs/design/platforms/android/controls.md#a-buttons-size
    func setLeastSize(width: Int32, height: Int32) {
        Java.call(reference, JavaAPI.setMinWidth, .int(width))
        Java.call(reference, JavaAPI.setMinimumWidth, .int(width))
        Java.call(reference, JavaAPI.setMinHeight, .int(height))
        Java.call(reference, JavaAPI.setMinimumHeight, .int(height))
    }

    /// A click is the button's own event, and a tap as any view's.
    override func clicked() {
        onClicked?()
        super.clicked()
    }

    override func held(_ holding: Bool) {
        (holding ? onPressed : onReleased)?()
    }

    // MARK: - Its look

    /// The button's fill: its look is drawn again with it.
    override func setBackground(_ value: HostValue?) {
        look.fill = value
        drawLook()
    }

    /// The button's outline and corners, in points; none of them, and no fill, keeps the theme's look.
    func setOutline(color: HostValue?, width: Double?, cornerRadius: Double?) {
        look.stroke = color
        look.strokeWidth = width ?? 0
        look.cornerRadius = cornerRadius ?? 0
        drawLook()
    }

    /// One shape under the platform's pressed ripple, or the theme's background where nothing is said.
    /// Design: docs/design/platforms/android/controls.md#a-buttons-look
    private func drawLook() {
        guard look.fill != nil || look.stroke != nil || look.cornerRadius > 0 else { return showBackground(nil) }

        let corners: AndroidShapeDrawable.Shape =
            look.cornerRadius > 0 ? .rounded(Array(repeating: look.cornerRadius, count: 4)) : .rectangle
        let shape = AndroidShapeDrawable()
        shape.setShape(corners, density: density)
        shape.setFill(look.fill)
        shape.setStroke(look.stroke, width: look.strokeWidth * density)
        let mask = AndroidShapeDrawable()
        mask.setShape(corners, density: density)
        mask.setFill(Color("#000000").propValue)

        let pressable = withExtendedLifetime((shape, mask)) {
            Java.callStaticObject(
                JavaAPI.views, JavaAPI.pressable,
                .object(AndroidRenderer.context), .object(shape.reference), .object(mask.reference))
        }
        showBackground(pressable.map(JavaObject.init))
    }

    // MARK: - Its icon

    /// The picture beside the words `spacing` points away - the platform's gap for nil - or alone where
    /// there are none, filling its room as `aspect` says.
    func setIcon(_ source: ImageSource?, position: IconPosition, spacing: Double?, aspect: Aspect) {
        let file = source?.file ?? ""
        if file != icon.file {
            letGoOfIcon()
            icon.file = file
            icon.picture = file.isEmpty ? nil : AndroidPictures.take(named: file, sample: 1)
        }
        icon.position = position
        icon.spacing = spacing
        icon.aspect = aspect
        showIcon(room: placedSize)
    }

    /// The words decide where the icon goes: beside them, or alone in the middle.
    override func setText(_ text: String) {
        super.setText(text)
        hasWords = !text.isEmpty
        showIcon(room: placedSize)
    }

    /// An icon standing alone is sized to the room the button is placed in, before it is placed there; a
    /// button only moving keeps it.
    override func layout(_ place: Rect) {
        let room = (width: pixels(place.width), height: pixels(place.height))
        if !hasWords, placedSize.map({ $0 != room }) ?? true { showIcon(room: room) }
        super.layout(place)
    }

    /// The padding is the icon's room too.
    override func setPadding(_ insets: Insets?) {
        super.setPadding(insets)
        showIcon(room: placedSize)
    }

    override func detach() {
        super.detach()
        onClicked = nil
        onPressed = nil
        onReleased = nil
        letGoOfIcon()
    }

    /// Puts the icon on the button when what shows changed: beside its words at its own size, or alone,
    /// sized to the room inside the padding as its aspect says.
    private func showIcon(room: (width: Int32, height: Int32)?) {
        let alone = hasWords ? (width: Int32(0), height: Int32(0)) : iconSizeAlone(in: room)
        let shown = Icon.Shown(
            file: icon.file, position: icon.position, spacing: icon.spacing, words: hasWords,
            width: alone.width, height: alone.height)
        guard shown != shownIcon else { return }
        shownIcon = shown

        let position: Int32 = switch icon.position {
        case .leading: 0
        case .trailing: 1
        case .top: 2
        case .bottom: 3
        }
        withExtendedLifetime(icon.picture) {
            Java.callStatic(
                JavaAPI.views, JavaAPI.setIcon, .object(reference), .object(icon.picture?.reference),
                .int(position), .int(icon.spacing.map(pixels) ?? -1), .int(alone.width), .int(alone.height))
        }
    }

    /// The icon's size shown alone: the room inside the padding, filled as the aspect says.
    private func iconSizeAlone(in room: (width: Int32, height: Int32)?) -> (width: Int32, height: Int32) {
        guard let room, !icon.file.isEmpty, let size = AndroidPictures.size(named: icon.file),
              size.width > 0, size.height > 0
        else { return (0, 0) }

        let inside = (
            width: Double(room.width - Java.callInt(reference, JavaAPI.getPaddingLeft)
                - Java.callInt(reference, JavaAPI.getPaddingRight)),
            height: Double(room.height - Java.callInt(reference, JavaAPI.getPaddingTop)
                - Java.callInt(reference, JavaAPI.getPaddingBottom)))

        switch icon.aspect {
        case .center:
            return size
        case .stretch:
            return (Int32(max(inside.width, 0)), Int32(max(inside.height, 0)))
        case .fit, .fill:
            let scale = max(0, min(inside.width / Double(size.width), inside.height / Double(size.height)))
            return (Int32((Double(size.width) * scale).rounded()), Int32((Double(size.height) * scale).rounded()))
        }
    }

    /// Lets go of the icon's picture.
    private func letGoOfIcon() {
        if icon.picture != nil { AndroidPictures.letGo(named: icon.file, sample: 1) }
        icon.picture = nil
    }

    /// What a button draws itself with.
    private struct Look {
        var fill: HostValue?
        var stroke: HostValue?
        var strokeWidth: Double = 0
        var cornerRadius: Double = 0
    }

    /// A button's icon.
    private struct Icon {
        var file = ""
        var position: IconPosition = .leading
        var spacing: Double?
        var aspect: Aspect = .fit
        var picture: JavaObject?

        /// What an icon shows as: its picture, where, and its size alone in pixels.
        struct Shown: Equatable {
            let file: String
            let position: IconPosition
            let spacing: Double?
            let words: Bool
            let width: Int32
            let height: Int32
        }
    }
}
