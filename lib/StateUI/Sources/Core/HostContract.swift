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
            .absoluteLayout, .activityIndicator, .border, .boxView, .button,
            .datePicker, .editor, .entry, .graphicsView,
            .hStack, .image, .label, .picker,
            .progressBar, .scrollView, .searchBar, .slider, .stepper, .switch,
            .timePicker, .vStack, .webView,
        ]),
        (.adaptive, [
            .contentPage, .flyoutPage, .navigationPage, .tabbedPage, .titleBar,
        ]),
        (.stateUI, [
            .checkBox, .ellipse, .grid, .imageButton,
            .indicatorView, .line, .path, .polygon, .polyline, .radioButton,
            .rectangle, .refreshView, .roundRectangle, .swipeView,
        ]),
        (.structure, [
            .application, .composed, .content, .contextFlyout, .formattedString,
            .leadingContent, .menuBarItem, .menuBarItems, .menuFlyoutItem,
            .menuFlyoutSeparator, .menuFlyoutSubItem, .modalStack,
            .navigationPageTitleView, .overlay, .scene, .setters, .span, .swipeItem,
            .swipeItems, .toolbarItem, .toolbarItems, .trailingContent,
            .visualState, .window,
        ]),
        (.provider, [.map, .pin]),
    ])

    /// The owner of every `Prop` declared by StateUI.
    public static let properties: [Prop: HostPropertyOwner] = table([
        (.native, [
            .allowDrop, .anchorX, .anchorY, .aspect,
            .automationExcludedWithChildren, .automationId,
            .automationIsInAccessibleTree, .autoSize, .background,
            .backgroundColor, .borderColor, .borderWidth, .canDrag,
            .cascadeInputTransparent, .characterSpacing, .color,
            .cornerRadius, .cursorPosition, .date, .dragText, .flowDirection,
            .fontAttributes, .fontFamily, .fontSize, .format, .heightRequest,
            .horizontalOptions, .horizontalTextAlignment, .imageSource,
            .increment, .inputTransparent, .isAnimationPlaying,
            .isClippedToBounds, .isEnabled, .isOpaque, .isOpen, .isPassword,
            .isPresented, .isReadOnly, .isRunning, .isScrollEnabled,
            .isSpellCheckEnabled, .isTextPredictionEnabled, .isToggled,
            .isVisible, .lineBreakMode, .lineHeight, .margin, .maximum,
            .maximumDate, .maximumHeight, .maximumHeightRequest,
            .maximumTrackColor, .maximumWidth, .maximumWidthRequest,
            .maxLength, .maxLines, .minimum, .minimumDate, .minimumHeight,
            .minimumHeightRequest, .minimumTrackColor, .minimumWidth,
            .minimumWidthRequest, .offColor, .onColor, .opacity, .orientation,
            .padding, .placeholder, .placeholderColor, .progress,
            .progressColor, .renderTransform, .rotation, .rotationX, .rotationY,
            .scale, .scaleX, .scaleY, .scrollMomentum, .scrollStep,
            .selectedIndex, .selectionLength, .semanticDescription,
            .semanticHeadingLevel, .semanticHint, .snapFrom, .snapInterval,
            .snapsAtMost, .source, .spacing, .text, .textColor,
            .textDecorations, .textTransform, .thumbColor, .time, .title,
            .titleColor, .translationX, .translationY, .value,
            .verticalOptions, .verticalTextAlignment, .widthRequest, .zIndex,
        ]),
        (.adaptive, [
            .autoHide, .barBackground,
            .barBackgroundColor, .barTextColor, .cancelButtonColor,
            .clearButtonVisibility, .contentLayout, .floatsOnTop,
            .flyoutLayoutBehavior, .fontAutoScalingEnabled, .foregroundColor,
            .horizontalScrollBarVisibility, .icon,
            .iconImageSource, .isDestructive, .isGestureEnabled,
            .isMaximizable, .isMinimizable, .keyboard,
            .navigationPageBackButtonTitle,
            .navigationPageHasBackButton, .navigationPageHasNavigationBar,
            .order, .priority, .returnType, .safeAreaEdges, .searchIconColor,
            .selectedTabColor, .subtitle, .textType, .thumbImageSource,
            .unselectedTabColor, .userAgent,
            .verticalScrollBarVisibility,
        ]),
        (.stateUI, [
            .columnDefinitions, .columnSpacing, .count, .data, .fill, .fillRule,
            .gridColumn, .gridColumnSpan,
            .gridRow, .gridRowSpan, .groupName, .hideSingle, .indicatorColor,
            .indicatorSize, .indicatorsShape, .isChecked, .isRefreshEnabled,
            .isRefreshing, .maximumVisible, .mode, .points,
            .position, .radiusX, .radiusY, .refreshColor, .rowDefinitions,
            .rowSpacing, .selectedIndicatorColor, .side, .stroke,
            .strokeDashArray, .strokeDashOffset, .strokeLineCap,
            .strokeLineJoin, .strokeMiterLimit, .strokeShape, .strokeThickness,
            .swipeBehaviorOnInvoked, .threshold, .x1, .x2, .y1, .y2,
        ]),
        (.structure, [
            .absoluteLayoutBounds, .absoluteLayoutFlags, .content,
            .currentPage, .drawable, .frame, .group, .height, .itemsSource,
            .name, .numberOfTapsRequired, .panTouchCount, .panXChannel,
            .panYChannel, .scroll, .style, .swipeDirection, .swipeThreshold,
            .width, .windowType, .windowValue, .x, .y,
        ]),
        (.provider, [
            .address, .isShowingUser, .isTrafficEnabled, .isZoomEnabled,
            .label, .location, .mapType, .region, .type,
        ]),
    ])

    /// The owner of every `Event` declared by StateUI.
    public static let events: [Event: HostEventOwner] = table([
        (.native, [
            .canGoBackChanged, .canGoForwardChanged, .clicked, .closed,
            .completed, .dateSelected, .dragCompleted, .dragInteraction,
            .dragLeave, .dragOver, .dragStarted, .dragStarting, .drop,
            .dropCompleted, .endInteraction, .frameChanged, .heightChanged,
            .isFocusedChanged, .navigated, .navigating, .opened, .panUpdated,
            .pinchUpdated, .pointerEntered, .pointerExited, .pointerMoved,
            .pointerPressed, .pointerReleased, .pressed, .processTerminated,
            .released, .scrollStopped, .scrollXChanged, .scrollYChanged,
            .searchButtonPressed, .selectedIndexChanged, .snapItemChanged,
            .startInteraction, .swiped, .tapped, .textChanged, .timeSelected,
            .toggled, .valueChanged, .widthChanged,
        ]),
        (.adaptive, [
            .activated, .appearing, .created, .currentPageChanged,
            .deactivated, .destroying, .disappearing, .isPresentedChanged,
            .modalPopped, .navigatedFrom, .navigatedTo, .navigatingFrom,
            .popped, .resumed, .stopped, .windowClosed,
            .windowRestored,
        ]),
        (.stateUI, [
            .checkedChanged, .invoked, .isRefreshingChanged, .refreshing,
            .swipeChanging, .swipeEnded, .swipeStarted, .visualStateChanged,
        ]),
        (.provider, [.infoWindowClicked, .mapClicked, .markerClicked]),
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
