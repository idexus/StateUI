// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The ownership table for StateUI's built-in host vocabulary.
//
// NodeType and Prop stay open so an application can register a control of its
// own. The names StateUI itself declares are different: every one has exactly
// one owner here. That makes a new built-in spelling an architectural decision
// instead of an unclassified value that one host can silently ignore.

/// The layer responsible for a built-in control in the settled host boundary.
@_spi(Host) public enum HostControlOwner: Equatable, Sendable {
    /// Every base host presents the capability with its native toolkit.
    case native

    /// Every base host presents the capability according to platform shell
    /// conventions while preserving the StateUI state contract.
    case adaptive

    /// StateUI derives the control from smaller primitives before a settled
    /// native host receives the tree.
    case stateUI

    /// The node carries nonvisual structure or protocol metadata.
    case structure

    /// An optional package supplies the capability; it is not a base-host
    /// requirement.
    case provider
}

/// The layer responsible for a built-in property in the settled host boundary.
@_spi(Host) public enum HostPropertyOwner: Equatable, Sendable {
    /// Every base host implements the same observable capability.
    case native

    /// A host follows its platform convention and has a documented neutral
    /// behavior where the platform has no corresponding capability.
    case adaptive

    /// StateUI consumes the property while deriving a composed control.
    case stateUI

    /// The property carries protocol data rather than configuring a visual
    /// platform object.
    case structure

    /// An optional provider owns the property with its control family.
    case provider
}

/// The layer responsible for reporting a built-in event.
@_spi(Host) public enum HostEventOwner: Equatable, Sendable {
    /// A native control or recognizer reports the semantic event directly.
    case native

    /// A host translates platform lifecycle or presentation callbacks into the
    /// StateUI event while following the platform's own conventions.
    case adaptive

    /// StateUI derives the event while composing a richer control or behavior.
    case stateUI

    /// An optional provider reports the event with its control family.
    case provider
}

/// The single ownership contract for StateUI's built-in control, property, and
/// event vocabulary.
///
/// Application-defined tokens intentionally have no entry. A host resolves
/// those through its application control registry. The tables state the
/// settled boundary and prevent an inherited implementation detail from
/// becoming the design.
@_spi(Host) public struct HostContract {
    /// The owner of every `NodeType` declared by StateUI.
    public static let controls: [NodeType: HostControlOwner] = table([
        (.native, [
            .absoluteLayout, .activityIndicator, .border, .colorBox, .button,
            .datePicker, .textEditor, .textField, .canvas,
            .hStack, .image, .label, .picker,
            .progressBar, .scrollView, .searchField, .slider, .stepper, .switch,
            .timePicker, .vStack, .webView,
        ]),
        (.adaptive, [
            .page, .splitView, .navigationStack, .tabbedView, .titleBar,
        ]),
        (.stateUI, [
            .checkBox, .ellipse, .grid,
            .positionIndicator, .line, .path, .polygon, .polyline, .radioButton,
            .rectangle, .refreshView, .swipeView,
        ]),
        (.structure, [
            .application, .content, .contextMenu, .spans,
            .leadingContent, .menu, .menuBar, .menuItem,
            .menuSeparator, .modalStack,
            .titleView, .overlay, .scene, .setters, .span, .swipeAction,
            .swipeActions, .toolbarItem, .toolbarItems, .trailingContent,
            .visualState, .window,
        ]),
        (.provider, [.map, .pin]),
    ])

    /// The owner of every `Prop` declared by StateUI.
    public static let properties: [Prop: HostPropertyOwner] = table([
        (.native, [
            .allowDrop, .pivotX, .pivotY, .aspect,
            .automationExcludedWithChildren, .accessibilityIdentifier,
            .isAccessibilityHidden, .growsWithText, .background,
            .borderColor, .borderWidth, .canDrag,
            .characterSpacing, .color,
            .cornerRadius, .cursorPosition, .date, .dragText, .layoutDirection,
            .fontAttributes, .fontFamily, .fontSize, .format, .height,
            .horizontalAlignment, .horizontalTextAlignment,
            .step, .ignoresInput, .isAnimating, .letsInputThrough,
            .clipsContent, .isEnabled, .isOpen, .isPassword,
            .isSidebarVisible, .isReadOnly, .isRunning, .isScrollEnabled,
            .isSpellCheckEnabled, .isTextPredictionEnabled, .isOn,
            .isVisible, .lineBreak, .lineHeight, .margin, .maximum,
            .maximumDate, .maximumHeight,
            .maximumWidth,
            .maximumLength, .maximumLines, .minimum, .minimumDate, .minimumHeight,
            .minimumWidth, .opacity, .orientation,
            .padding, .placeholder, .placeholderColor, .progress,
            .renderTransform, .rotation, .rotationX, .rotationY,
            .scale, .scaleX, .scaleY,
            .selectedIndex, .selectionLength, .accessibilityLabel,
            .accessibilityHeadingLevel, .accessibilityHint,
            .source, .spacing, .text, .textColor,
            .textDecorations, .textCase, .time, .title,
            .translationX, .translationY, .value,
            .verticalAlignment, .verticalTextAlignment, .width, .zIndex,
        ]),
        (.adaptive, [
            .barBackgroundColor, .barForegroundColor,
            .showsClearButton, .iconPosition, .iconSpacing, .floatsOnTop,
            .fontAutoScalingEnabled, .hidesWhenInactive,
            .horizontalScrollBarVisibility, .icon,
            .isDestructive,
            .isMaximizable, .isMinimizable, .isTranslucent, .inputPurpose,
            .backButtonTitle,
            .hasBackButton, .hasNavigationBar,
            .placement, .priority, .returnKey, .avoidsSafeArea,
            .subtitle, .tint, .userAgent,
            .verticalScrollBarVisibility,
        ]),
        (.stateUI, [
            .columns, .columnSpacing, .count, .data, .fill, .fillRule,
            .gridColumn, .gridColumnSpan,
            .gridRow, .gridRowSpan, .groupName, .hideSingle, .indicatorColor,
            .indicatorSize, .indicatorsShape, .isRefreshEnabled,
            .isRefreshing, .maximumVisible, .mode, .points,
            .position, .rows,
            .rowSpacing, .selectedIndicatorColor, .side, .stroke,
            .strokeDashPattern, .strokeDashOffset, .strokeLineCap,
            .strokeLineJoin, .strokeMiterLimit, .shape, .strokeWidth,
            .swipeBehaviorOnInvoked, .threshold, .x1, .x2, .y1, .y2,
        ]),
        (.structure, [
            .absoluteLayoutBounds, .absoluteLayoutProportions,
            .currentPage, .drawable, .frame, .group, .options,
            .name, .tapCount, .panTouchCount, .panXChannel,
            .panYChannel, .scrollOffset, .style, .swipeDirection, .swipeThreshold,
            .windowType, .windowValue, .x, .y,
        ]),
        (.provider, [
            .address, .showsUserLocation, .isTrafficEnabled, .isZoomEnabled,
            .label, .location, .mapType, .region, .type,
        ]),
    ])

    /// The owner of every `Event` declared by StateUI.
    public static let events: [Event: HostEventOwner] = table([
        (.native, [
            .canGoBackChanged, .canGoForwardChanged, .clicked, .closed,
            .submitted, .dateChanged, .dragCompleted, .dragged,
            .dragLeave, .dragOver, .dragStarted, .dragStarting, .drop,
            .dropCompleted, .frameChanged,
            .isFocusedChanged, .navigated, .navigating, .opened, .panUpdated,
            .pinchUpdated, .pointerEntered, .pointerExited, .pointerMoved,
            .pointerPressed, .pointerReleased, .pressed, .processTerminated,
            .released, .scrollStopped, .scrollXChanged, .scrollYChanged,
            .selectedIndexChanged,
            .swiped, .tapped, .textChanged, .timeChanged,
            .toggled, .valueChanged,
        ]),
        (.adaptive, [
            .activated, .appearing, .created, .currentPageChanged,
            .deactivated, .destroying, .disappearing, .isSidebarVisibleChanged,
            .modalPopped, .navigatedFrom, .navigatedTo, .navigatingFrom,
            .popped, .resumed, .stopped, .windowClosed,
            .windowRestored,
        ]),
        (.stateUI, [
            .isRefreshingChanged, .refreshRequested,
            .swipeChanging, .swipeEnded, .swipeStarted, .visualStateChanged,
        ]),
        (.provider, [.pinDetailsClicked, .mapClicked, .pinClicked]),
    ])

    private static func table<Key: Hashable, Owner>(
        _ groups: [(Owner, [Key])]
    ) -> [Key: Owner] {
        var result: [Key: Owner] = [:]

        for (owner, keys) in groups {
            for key in keys {
                precondition(result.updateValue(owner, forKey: key) == nil,
                             "A built-in host token has more than one owner")
            }
        }
        return result
    }
}
