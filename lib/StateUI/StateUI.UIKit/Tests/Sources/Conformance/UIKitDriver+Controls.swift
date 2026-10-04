// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance

/// What the UIKit driver reads of a control's own: a label's lines, a field's and an editor's, a button's
/// configuration, a layout's box and a shape's paint on their layers, a picture's mode - each from UIKit itself.
/// Design: docs/design/platforms/uikit/conformance.md#what-the-driver-reads
extension UIKitDriver {
    static func controlHolds(_ property: Prop, _ view: UIView) throws -> HostValue? {
        view.layoutIfNeeded()
        if let shape = view as? UIKitShapeView { return try shapeHolds(property, shape) }
        if let layout = view as? UIKitLayoutView, let held = boxHolds(property, layout) { return held }
        if let button = view as? UIKitButtonView { return buttonHolds(property, button) }
        switch (property, view) {
        case (.maximumLines, let label as UILabel): return label.numberOfLines.propValue
        case (.lineBreak, let label as UILabel):
            return lineBreak(label.lineBreakMode).propValue
        case (.horizontalTextAlignment, let label as UILabel): return alignment(label.textAlignment, in: label).propValue
        case (.horizontalTextAlignment, let field as UITextField):
            return alignment(field.textAlignment, in: field).propValue
        case (.horizontalTextAlignment, let editor as UITextView):
            return alignment(editor.textAlignment, in: editor).propValue
        case (.placeholderColor, let field as UITextField):
            guard let placeholder = field.attributedPlaceholder, placeholder.length > 0 else { return nil }
            return (placeholder.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor)
                .map { color($0).propValue }
        case (.placeholderColor, let editor as UIKitTextEditorView):
            return editor.subviews.lazy.compactMap { $0 as? UILabel }.first?.textColor.map { color($0).propValue }
        case (.inputPurpose, let field as UITextField):
            return purpose(field.keyboardType, spelling: field.spellCheckingType).propValue
        case (.inputPurpose, let editor as UITextView):
            return purpose(editor.keyboardType, spelling: editor.spellCheckingType).propValue
        case (.contentMode, let image as UIImageView):
            let aspects: [UIView.ContentMode: StateUI.ContentMode] = [
                .scaleAspectFit: .fit, .scaleAspectFill: .fill, .scaleToFill: .stretch, .center: .center,
            ]
            return aspects[image.contentMode]?.propValue
        default: return nil
        }
    }

    /// A layout's box: what clips it, the colour its fill layer paints and the outline its stroke layer draws.
    private static func boxHolds(_ property: Prop, _ layout: UIKitLayoutView) -> HostValue? {
        let layers = layout.layer.sublayers ?? []
        let outline = layers.first { $0.zPosition == -1 } as? CAShapeLayer
        switch property {
        case .clipsContent: return (layout.clipsToBounds || layout.layer.mask != nil).propValue
        case .background:
            let fill = layers.first { $0.zPosition == -2 && !($0 is CAGradientLayer) }
            return fill?.backgroundColor.map { Background.color(color(UIColor(cgColor: $0))).propValue }
        case .stroke: return outline?.strokeColor.map { Brush.solidColor(color(UIColor(cgColor: $0))).propValue }
        case .lineWidth: return Double(outline?.lineWidth ?? 0).propValue
        default: return nil
        }
    }

    /// A shape's paint: the colour over its fill and its outline, and how its outline's mask draws the line.
    private static func shapeHolds(_ property: Prop, _ shape: UIKitShapeView) throws -> HostValue? {
        let painted = shape.layer.sublayers ?? []
        let fill = painted.first { ($0.mask as? CAShapeLayer)?.fillColor != nil }
        let stroke = painted.first { ($0.mask as? CAShapeLayer)?.strokeColor != nil }
        let line = stroke?.mask as? CAShapeLayer
        let outlines: Set<Prop> = [
            .lineWidth, .dash, .dashPhase, .lineCap, .lineJoin, .miterLimit,
        ]
        if line == nil, outlines.contains(property) { throw DriverCannot("read the line of a shape drawing no outline") }
        let width = Double(line?.lineWidth ?? 0)
        switch property {
        case .fill: return fill?.backgroundColor.map { Brush.solidColor(color(UIColor(cgColor: $0))).propValue }
        case .stroke: return stroke?.backgroundColor.map { Brush.solidColor(color(UIColor(cgColor: $0))).propValue }
        case .lineWidth: return width.propValue
        case .dash:
            // Lengths in points on UIKit: back in the outline's widths.
            let lengths = line?.lineDashPattern?.map(\.doubleValue) ?? []
            return lengths.map { width > 0 ? $0 / width : 0 }.propValue
        case .dashPhase: return (width > 0 ? Double(line?.lineDashPhase ?? 0) / width : 0).propValue
        case .lineCap:
            let caps: [CAShapeLayerLineCap: LineCap] = [.butt: .flat, .round: .round, .square: .square]
            return line.flatMap { caps[$0.lineCap] }?.propValue
        case .lineJoin:
            let joins: [CAShapeLayerLineJoin: LineJoin] = [.miter: .miter, .round: .round, .bevel: .bevel]
            return line.flatMap { joins[$0.lineJoin] }?.propValue
        case .miterLimit: return line.map { Double($0.miterLimit).propValue }
        default: return nil
        }
    }

    /// A button's box, its icon's place and room, and how its caption breaks, as its configuration holds them.
    private static func buttonHolds(_ property: Prop, _ button: UIKitButtonView) -> HostValue? {
        guard let configuration = button.configuration else { return nil }
        let box = configuration.background
        switch property {
        case .background: return box.backgroundColor.map { Background.color(color($0)).propValue }
        case .stroke: return box.strokeColor.map { Brush.solidColor(color($0)).propValue }
        case .lineWidth: return Double(box.strokeWidth).propValue
        case .shape:
            if configuration.cornerStyle == .capsule { return ContainerShape.ellipse.propValue }
            let radius = Double(box.cornerRadius)
            return (radius > 0 ? ContainerShape.roundedRectangle(radius) : .rectangle).propValue
        case .iconPosition:
            let positions: [(NSDirectionalRectEdge, IconPosition)] = [
                (.leading, .leading), (.top, .top), (.trailing, .trailing), (.bottom, .bottom),
            ]
            return positions.first { $0.0 == configuration.imagePlacement }?.1.propValue
        case .iconSpacing: return Double(configuration.imagePadding).propValue
        case .lineBreak: return lineBreak(configuration.titleLineBreakMode).propValue
        default: return nil
        }
    }

    /// StateUI's break for UIKit's.
    private static func lineBreak(_ mode: NSLineBreakMode) -> LineBreak {
        switch mode {
        case .byClipping: .noWrap
        case .byCharWrapping: .characterWrap
        case .byTruncatingHead: .headTruncation
        case .byTruncatingTail: .tailTruncation
        case .byTruncatingMiddle: .middleTruncation
        default: .wordWrap
        }
    }

    /// Where the words stand across the view, as UIKit aligns them, read in the view's own direction.
    private static func alignment(_ native: NSTextAlignment, in view: UIView) -> TextAlignment {
        let leftToRight = view.effectiveUserInterfaceLayoutDirection == .leftToRight
        return switch native {
        case .center: .center
        case .right: leftToRight ? .end : .start
        case .left: leftToRight ? .start : .end
        default: .start
        }
    }

    /// What the keyboard a field raises says it is for.
    private static func purpose(_ keyboard: UIKeyboardType, spelling: UITextSpellCheckingType) -> InputPurpose {
        switch keyboard {
        case .emailAddress: .email
        case .URL: .url
        case .phonePad: .telephone
        case .decimalPad: .numeric
        default: spelling == .no ? .plain : .default
        }
    }
}
