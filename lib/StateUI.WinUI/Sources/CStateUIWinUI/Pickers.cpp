// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A picker: WinUI's ComboBox, its choices, the one chosen - told through
// `chosen` - its placeholder while none is, and its list opening and closing,
// told through `presented`.
// Design: docs/design/platforms/winui/controls.md#a-picker

#include "Automation.h"

#include <winrt/Windows.UI.Xaml.Interop.h>

using namespace stateui;

extern "C" StateUIObjectRef stateui_winui_picker_make(int64_t view) {
    try {
        controls::ComboBox box;
        box.SelectionChanged([view](IInspectable const &sender, controls::SelectionChangedEventArgs const &) {
            callbacks.chosen(view, sender.as<controls::ComboBox>().SelectedIndex());
        });
        box.DropDownOpened([view](IInspectable const &, IInspectable const &) { callbacks.presented(view, true); });
        box.DropDownClosed([view](IInspectable const &, IInspectable const &) { callbacks.presented(view, false); });
        return detach(box);
    } catch (winrt::hresult_error const &error) {
        report(error, "making a picker");
        return nullptr;
    }
}

extern "C" void stateui_winui_picker_set_options(StateUIObjectRef handle, char const *const *options, int32_t count) {
    try {
        auto items = borrow<controls::ComboBox>(handle).Items();
        items.Clear();
        for (int32_t index = 0; index < count; ++index) items.Append(winrt::box_value(text(options[index])));
    } catch (winrt::hresult_error const &error) {
        report(error, "giving a picker its choices");
    }
}

extern "C" void stateui_winui_picker_set(StateUIObjectRef handle, int32_t selected, bool writeSelected, char const *title) {
    try {
        auto box = borrow<controls::ComboBox>(handle);
        box.PlaceholderText(text(title));
        auto count = static_cast<int32_t>(box.Items().Size());
        if (writeSelected) box.SelectedIndex(selected >= 0 && selected < count ? selected : -1);
    } catch (winrt::hresult_error const &error) {
        report(error, "choosing in a picker");
    }
}

extern "C" void stateui_winui_picker_set_alignment(StateUIObjectRef handle, int32_t alignment) {
    try {
        // The choice shown and every choice in the list stand alike across the picker.
        auto box = borrow<controls::ComboBox>(handle);
        auto across = alignment == 1 ? xaml::HorizontalAlignment::Center
                      : alignment == 2 ? xaml::HorizontalAlignment::Right
                                       : xaml::HorizontalAlignment::Left;
        box.HorizontalContentAlignment(across);
        xaml::Style items{winrt::xaml_typename<controls::ComboBoxItem>()};
        items.Setters().Append(xaml::Setter(controls::Control::HorizontalContentAlignmentProperty(), winrt::box_value(across)));
        box.ItemContainerStyle(items);
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a picker's choices across it");
    }
}

extern "C" void stateui_winui_picker_set_open(StateUIObjectRef handle, bool open) {
    try {
        borrow<controls::ComboBox>(handle).IsDropDownOpen(open);
    } catch (winrt::hresult_error const &error) {
        report(error, "opening a picker's list");
    }
}

extern "C" bool stateui_winui_picker_is_open(StateUIObjectRef handle) {
    try {
        return borrow<controls::ComboBox>(handle).IsDropDownOpen();
    } catch (winrt::hresult_error const &error) {
        report(error, "reading whether a picker's list shows");
        return false;
    }
}

extern "C" int32_t stateui_winui_picker_selected(StateUIObjectRef handle) {
    try {
        return borrow<controls::ComboBox>(handle).SelectedIndex();
    } catch (winrt::hresult_error const &error) {
        report(error, "reading a picker's choice");
        return -1;
    }
}

extern "C" void stateui_winui_picker_open_as_user(StateUIObjectRef handle, bool open) {
    try {
        auto expanding = pattern<provider::IExpandCollapseProvider>(borrow<controls::ComboBox>(handle), PatternInterface::ExpandCollapse);
        if (open) expanding.Expand();
        else expanding.Collapse();
    } catch (winrt::hresult_error const &error) {
        report(error, "opening a picker's list as the user");
    }
}

extern "C" void stateui_winui_picker_choose_as_user(StateUIObjectRef handle, int32_t index) {
    try {
        borrow<controls::ComboBox>(handle).SelectedIndex(index);
    } catch (winrt::hresult_error const &error) {
        report(error, "choosing in a picker as the user");
    }
}
