// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A Button: an `android.widget.Button` whose click reaches Swift through its `StateUIListener`.
@MainActor
final class AndroidButtonView: AndroidTextualView {
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

    /// The pixels added to each side of the padding where the button is placed, standing its icon and its words
    /// together in the middle; not the button's own, so left out of what it measures.
    private var sideRoom: Int32 = 0

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

    /// A click is the button's own event, and a tap as any view's; a button whose click opens its menu opens it, and
    /// so does a split button's arrow.
    override func clicked() {
        let at = Java.callFloat(listener.reference, JavaAPI.takeDownX)
        if opening == .click || opening == .arrow && onArrow(at) { showMenu() } else { onClicked?() }
        super.clicked()
    }

    /// How the button opens its menu, whether it shows the arrow saying its click does, and what its menu writes
    /// into a menu as it opens.
    private(set) var opening = ButtonMenuOpening.none
    private(set) var showsArrow = false
    private(set) var writeMenu: ((jobject) -> Void)?

    /// How wide a split button's arrow stands, the arrow's side - Material's arrow fills the middle half of it
    /// across - how far the mark after the words stands from them, and how high the line setting the arrow off, in
    /// points.
    private static let arrowWidth = 32.0
    private static let arrowSide = 18.0
    private static let markGap = 6.0
    private static let lineHeight = 20.0

    /// Gives the button its menu, opened as `opening` says: by a click, an arrow after the words where `showsArrow`;
    /// by a split button's arrow, the click the button's own; or held. Android's Views draw no split button: its
    /// arrow is the button's, at its right edge, set off by a line, and a long press opens its menu too.
    /// Design: docs/design/platforms/android/controls.md#a-buttons-menu
    func setMenu(_ opening: ButtonMenuOpening, showsArrow: Bool, _ write: ((jobject) -> Void)?) {
        writeMenu = opening == .none ? nil : write
        let showsArrow = opening == .click && showsArrow
        guard opening != self.opening || showsArrow != self.showsArrow else { return }
        self.opening = opening
        longPressChanged()
        self.showsArrow = showsArrow
        rightRoom = opening == .arrow ? pixels(Self.arrowWidth)
            : showsArrow ? pixels(Self.arrowSide / 2 + Self.markGap) : 0
        paddingSet()
        shownIcon = nil
        showIcon(room: placedSize)
    }

    /// Whether a finger went down `x` pixels across the button on a split button's arrow.
    private func onArrow(_ x: Float) -> Bool {
        guard x >= 0, let width = placedSize?.width else { return false }
        return x >= Float(width - pixels(Self.arrowWidth))
    }

    /// A long press opens a split button's menu, and a held one's - before a drag of it.
    override func longClicked() -> Bool {
        guard opening == .arrow || opening == .hold else { return super.longClicked() }
        showMenu()
        return true
    }

    override var takesLongPress: Bool {
        opening == .arrow || opening == .hold || super.takesLongPress
    }

    /// Android's menu popping up at the button, its entries written as it opens.
    private func showMenu() {
        guard let writeMenu else { return }
        Java.frame {
            guard let popup = Java.callStaticObject(JavaAPI.menus, JavaAPI.popUpMenu, .object(reference)),
                  let items = Java.callObject(popup, JavaAPI.popupMenuItems)
            else { return }
            writeMenu(items)
            Java.call(popup, JavaAPI.showPopupMenu)
        }
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

    /// The button's outline and shape, the width in points and one where none is said; no outline, a plain
    /// rectangle and no fill keep the theme's look.
    func setOutline(stroke: HostValue?, width: Double?, shape: HostValue?) {
        look.stroke = stroke
        look.lineWidth = width
        look.shape = AndroidShapeDrawable.Shape(container: shape)
        drawLook()
    }

    /// The shape its look is drawn in, and the one its pressed ripple is kept within; none while the theme's
    /// look shows.
    private var drawn: (shape: AndroidShapeDrawable, mask: AndroidShapeDrawable)?

    /// The platform's coloured button - its background and words' colours - which the window's main action wears;
    /// nil for the theme's plain one.
    private var coloured: (background: JavaObject, words: JavaObject)?

    /// The theme's colours for an error, which a destructive action's words wear; nil for any other.
    private var critical: JavaObject?

    /// What the button stands for (`ButtonRoleLook`): the window's main action wears the platform's coloured button,
    /// its background where the button draws no look of its own and its words' colours where none is written; a
    /// destructive one's words stand in the theme's colour for an error where none is written. The way out stands
    /// plain.
    /// Design: docs/design/platforms/android/controls.md#a-buttons-look
    func setRole(_ role: ButtonRole?) {
        self.role = role
        // What the tree writes is weighed where the colours are used: these stand only where nothing is written.
        let look = ButtonRoleLook(role, fills: false, colorsWords: false)
        let colours = look.fillsInAccent != (coloured != nil)
        let words = look.wordsInCritical != (critical != nil)
        guard colours || words else { return }
        if colours {
            coloured = look.fillsInAccent ? Java.frame {
                let context = AndroidRenderer.context
                let background = Java.callStaticObject(JavaAPI.views, JavaAPI.colouredBackground, .object(context))
                let words = Java.callStaticObject(JavaAPI.views, JavaAPI.colouredWords, .object(context))
                return background.flatMap { background in words.map { (JavaObject(background), JavaObject($0)) } }
            } : nil
        }
        if words {
            critical = look.wordsInCritical ? Java.frame {
                Java.callStaticObject(JavaAPI.views, JavaAPI.errorWords, .object(AndroidRenderer.context))
                    .map(JavaObject.init)
            } : nil
        }
        drawLook()
        setTextColor(writtenTextColor)
    }

    /// The role the tree gave the button; nil for none.
    private(set) var role: ButtonRole?

    override var plainWordColours: JavaObject { coloured?.words ?? critical ?? super.plainWordColours }

    /// The words' colour, which an icon is drawn in too.
    override func setTextColor(_ color: HostValue?) {
        super.setTextColor(color)
        shownIcon = nil
        showIcon(room: placedSize)
    }

    /// One shape under the platform's pressed ripple, or the theme's background - the coloured button's for the
    /// main action - where nothing is said.
    /// Design: docs/design/platforms/android/controls.md#a-buttons-look
    private func drawLook() {
        guard look.fill != nil || look.stroke != nil || look.shape != .rectangle else {
            drawn = nil
            return showBackground(coloured?.background)
        }

        let corners = look.shape
        let shape = AndroidShapeDrawable()
        shape.setStroke(look.stroke, width: look.lineWidth, density: density)
        shape.setShape(corners, density: density)
        shape.setFill(look.fill)
        let mask = AndroidShapeDrawable()
        mask.setShape(corners, density: density)
        mask.setFill(Color(hex: 0x000000).propValue)
        drawn = (shape, mask)
        if let size = placedSize { sized(width: size.width, height: size.height) }

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
    func setIcon(_ source: HostPicture?, position: IconPosition, spacing: Double?, aspect: ContentMode) {
        if source != icon.source {
            letGoOfIcon()
            icon.source = source
            icon.size = source.flatMap(AndroidPictures.size(of:))
            icon.picture = source.flatMap { AndroidPictures.take($0, sample: 1) }
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
        standTogether(width: room.width)
        super.layout(place)
    }

    /// Measured as if the side room were not there: as wide again as it adds, less what it adds. With no words it
    /// holds its icon at its own size inside its padding, which Android, drawing it over the button, measures not.
    override func measure(width: Int32, height: Int32) -> (width: Int32, height: Int32) {
        let measured: (width: Int32, height: Int32)
        if sideRoom > 0 {
            let mode = width & ViewConstants.modes
            let widened = mode == ViewConstants.unspecified ? width : mode | ((width & ~ViewConstants.modes) + 2 * sideRoom)
            let wide = super.measure(width: widened, height: height)
            measured = (wide.width - 2 * sideRoom, wide.height)
        } else {
            measured = super.measure(width: width, height: height)
        }
        guard !hasWords, let size = icon.size else { return measured }

        func holding(_ spec: Int32, _ measured: Int32, _ least: Int32) -> Int32 {
            switch ViewConstants.mode(spec) {
            case ViewConstants.exactly: measured
            case ViewConstants.atMost: min(max(measured, least), ViewConstants.size(spec))
            default: max(measured, least)
            }
        }
        let across = Java.callInt(reference, JavaAPI.getPaddingLeft) + Java.callInt(reference, JavaAPI.getPaddingRight)
        let down = Java.callInt(reference, JavaAPI.getPaddingTop) + Java.callInt(reference, JavaAPI.getPaddingBottom)
        return (holding(width, measured.width, size.width + across), holding(height, measured.height, size.height + down))
    }

    /// Stands the icon beside the words in the middle with them, on a button `width` pixels wide.
    /// Design: docs/design/host/layout.md#a-buttons-picture-and-words
    private func standTogether(width: Int32) {
        let reference = reference
        let (left, top) = (Java.callInt(reference, JavaAPI.getPaddingLeft), Java.callInt(reference, JavaAPI.getPaddingTop))
        let (right, bottom) = (Java.callInt(reference, JavaAPI.getPaddingRight), Java.callInt(reference, JavaAPI.getPaddingBottom))
        var side: Int32 = 0
        if hasWords, icon.picture != nil {
            let gap = Java.callInt(reference, JavaAPI.getCompoundDrawablePadding)
            let picture = Java.callInt(reference, JavaAPI.getCompoundPaddingLeft)
                + Java.callInt(reference, JavaAPI.getCompoundPaddingRight) - left - right - gap
            side = Int32(ButtonArithmetic.sideRoom(
                Double(width - left - right + 2 * sideRoom), picture: Double(picture), gap: Double(gap),
                words: Double(wordsWidth), position: icon.position).rounded(.down))
        }
        guard side != sideRoom else { return }
        Java.call(reference, JavaAPI.setPadding,
                  .int(left - sideRoom + side), .int(top), .int(right - sideRoom + side), .int(bottom))
        sideRoom = side
    }

    /// The pixels the words take on one line, as the button's paint draws them.
    private var wordsWidth: Float {
        Java.frame {
            guard let paint = Java.callObject(reference, JavaAPI.getPaint) else { return 0 }
            let words = Java.string(text)
            defer { Java.release(local: words) }
            return Java.callFloat(paint, JavaAPI.measureText, .object(words))
        }
    }

    override func sized(width: Int32, height: Int32) {
        drawn?.shape.fit(width: width, height: height)
        drawn?.mask.fit(width: width, height: height)
    }

    /// The padding is the icon's room too.
    override func setPadding(_ insets: Insets?) {
        super.setPadding(insets)
        paddingSet()
        showIcon(room: placedSize)
    }

    override func showBackground(_ drawable: JavaObject?) {
        super.showBackground(drawable)
        paddingSet()
    }

    /// The padding was set afresh, with no side room in it: it is worked out again where the button stands.
    private func paddingSet() {
        sideRoom = 0
        if let placed = placedSize { standTogether(width: placed.width) }
    }

    override func detach() {
        super.detach()
        onClicked = nil
        onPressed = nil
        onReleased = nil
        writeMenu = nil
        letGoOfIcon()
    }

    /// Puts the icon on the button when what shows changed: beside its words at its own size, or alone,
    /// sized to the room inside the padding as its aspect says.
    private func showIcon(room: (width: Int32, height: Int32)?) {
        let alone = hasWords ? (width: Int32(0), height: Int32(0)) : iconSizeAlone(in: room)
        let shown = Icon.Shown(
            source: icon.source, position: icon.position, spacing: icon.spacing, words: hasWords,
            width: alone.width, height: alone.height, arrow: showsArrow || opening == .arrow)
        guard shown != shownIcon else { return }
        shownIcon = shown

        let position: Int32 = switch icon.position {
        case .start: 0
        case .end: 1
        case .top: 2
        case .bottom: 3
        }
        let splits = opening == .arrow
        let arrowRight = splits ? pixels((Self.arrowWidth - Self.arrowSide) / 2) : paddingRight - pixels(Self.arrowSide / 4)
        let arrow = shown.arrow ? Java.string(StateUI.Icon.down.androidDrawable) : nil
        defer { Java.release(local: arrow) }
        withExtendedLifetime(icon.picture) {
            Java.callStatic(
                JavaAPI.views, JavaAPI.setIcon, .object(reference), .object(icon.picture?.reference),
                .int(position), .int(icon.spacing.map(pixels) ?? -1), .int(alone.width), .int(alone.height),
                .int(rightRoom), .object(arrow), .bool(splits), .int(pixels(Self.arrowSide)),
                .int(arrowRight),
                .int(pixels(Self.arrowWidth)), .int(pixels(Self.lineHeight)))
        }
    }

    /// The icon's size shown alone: the room inside the padding, filled as the aspect says.
    private func iconSizeAlone(in room: (width: Int32, height: Int32)?) -> (width: Int32, height: Int32) {
        guard let room, let size = icon.size, size.width > 0, size.height > 0
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
        if let source = icon.source, icon.picture != nil { AndroidPictures.letGo(source, sample: 1) }
        icon.picture = nil
    }

    /// What a button draws itself with.
    private struct Look {
        var fill: HostValue?
        var stroke: HostValue?
        var lineWidth: Double?
        var shape = AndroidShapeDrawable.Shape.rectangle
    }

    /// A button's icon.
    private struct Icon {
        var source: HostPicture?
        var size: (width: Int32, height: Int32)?
        var position: IconPosition = .start
        var spacing: Double?
        var aspect: ContentMode = .fit
        var picture: JavaObject?

        /// What an icon shows as: its picture, where, and its size alone in pixels.
        struct Shown: Equatable {
            let source: HostPicture?
            let position: IconPosition
            let spacing: Double?
            let words: Bool
            let width: Int32
            let height: Int32
            let arrow: Bool
        }
    }
}
