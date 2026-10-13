// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A picker: WinUI's ComboBox, its choices, the one chosen - told through
// `chosen` - its placeholder while none is, and its list opening and closing,
// told through `presented`.
// Design: docs/design/platforms/winui/controls.md#a-picker

#include "Automation.h"

#include <algorithm>
#include <cstring>
#include <string>

#include <winrt/Windows.UI.Xaml.Interop.h>

using namespace stateui;

namespace {
    /// The object a picker's handle holds, whichever control its presentation made.
    IInspectable choicesOf(StateUIObjectRef handle) {
        IInspectable object{nullptr};
        winrt::copy_from_abi(object, handle);
        return object;
    }

    /// The place of a segment row's chosen item; -1 for none.
    int32_t chosenSegment(controls::SelectorBar const &bar) {
        uint32_t index = 0;
        return bar.SelectedItem() && bar.Items().IndexOf(bar.SelectedItem(), index) ? static_cast<int32_t>(index) : -1;
    }
}

extern "C" StateUIObjectRef stateui_winui_picker_make(int64_t view, int32_t kind) {
    try {
        if (kind == 1) {
            controls::SelectorBar bar;
            bar.SelectionChanged(guarded("handling SelectionChanged",
                [view](controls::SelectorBar const &sender, controls::SelectorBarSelectionChangedEventArgs const &) {
                callbacks.chosen(view, chosenSegment(sender));
            }));
            return detach(bar);
        }
        if (kind == 2) {
            controls::RadioButtons radios;
            radios.SelectionChanged(guarded("handling SelectionChanged",
                [view](IInspectable const &sender, controls::SelectionChangedEventArgs const &) {
                callbacks.chosen(view, sender.as<controls::RadioButtons>().SelectedIndex());
            }));
            return detach(radios);
        }
        controls::ComboBox box;
        box.SelectionChanged(guarded("handling SelectionChanged",
            [view](IInspectable const &sender, controls::SelectionChangedEventArgs const &) {
            callbacks.chosen(view, sender.as<controls::ComboBox>().SelectedIndex());
        }));
        box.DropDownOpened(guarded("handling DropDownOpened",
            [view](IInspectable const &, IInspectable const &) { callbacks.presented(view, true); }));
        box.DropDownClosed(guarded("handling DropDownClosed",
            [view](IInspectable const &, IInspectable const &) { callbacks.presented(view, false); }));
        return detach(box);
    } catch (...) {
        report("making a picker");
        return nullptr;
    }
}

extern "C" void stateui_winui_picker_set_options(StateUIObjectRef handle, char const *const *options, int32_t count) {
    try {
        auto object = choicesOf(handle);
        if (auto bar = object.try_as<controls::SelectorBar>()) {
            auto items = bar.Items();
            items.Clear();
            for (int32_t index = 0; index < count; ++index) {
                controls::SelectorBarItem item;
                item.Text(text(options[index]));
                items.Append(item);
            }
            return;
        }
        auto items = object.try_as<controls::RadioButtons>() ? object.as<controls::RadioButtons>().Items()
                                                             : object.as<controls::ComboBox>().Items();
        items.Clear();
        for (int32_t index = 0; index < count; ++index) items.Append(winrt::box_value(text(options[index])));
    } catch (...) {
        report("giving a picker its choices");
    }
}

extern "C" void stateui_winui_picker_set(StateUIObjectRef handle, int32_t selected, bool writeSelected, char const *title) {
    try {
        auto object = choicesOf(handle);
        if (auto bar = object.try_as<controls::SelectorBar>()) {
            auto items = bar.Items();
            if (writeSelected) bar.SelectedItem(selected >= 0 && selected < static_cast<int32_t>(items.Size()) ? items.GetAt(selected) : nullptr);
            return;
        }
        if (auto radios = object.try_as<controls::RadioButtons>()) {
            auto count = static_cast<int32_t>(radios.Items().Size());
            if (writeSelected) radios.SelectedIndex(selected >= 0 && selected < count ? selected : -1);
            return;
        }
        auto box = object.as<controls::ComboBox>();
        box.PlaceholderText(text(title));
        auto count = static_cast<int32_t>(box.Items().Size());
        if (writeSelected) box.SelectedIndex(selected >= 0 && selected < count ? selected : -1);
    } catch (...) {
        report("choosing in a picker");
    }
}

extern "C" void stateui_winui_picker_set_alignment(StateUIObjectRef handle, int32_t alignment) {
    try {
        // The choice shown and every choice in the list stand alike across the picker; segments and radio buttons
        // stand as WinUI stands them.
        auto box = choicesOf(handle).try_as<controls::ComboBox>();
        if (!box) return;
        auto across = alignment == 1 ? xaml::HorizontalAlignment::Center
                      : alignment == 2 ? xaml::HorizontalAlignment::Right
                                       : xaml::HorizontalAlignment::Left;
        box.HorizontalContentAlignment(across);
        xaml::Style items{winrt::xaml_typename<controls::ComboBoxItem>()};
        items.Setters().Append(xaml::Setter(controls::Control::HorizontalContentAlignmentProperty(), winrt::box_value(across)));
        box.ItemContainerStyle(items);
    } catch (...) {
        report("setting a picker's choices across it");
    }
}

extern "C" void stateui_winui_picker_set_open(StateUIObjectRef handle, bool open) {
    try {
        if (auto box = choicesOf(handle).try_as<controls::ComboBox>()) box.IsDropDownOpen(open);
    } catch (...) {
        report("opening a picker's list");
    }
}

extern "C" bool stateui_winui_picker_is_open(StateUIObjectRef handle) {
    try {
        auto box = choicesOf(handle).try_as<controls::ComboBox>();
        return box && box.IsDropDownOpen();
    } catch (...) {
        report("reading whether a picker's list shows");
        return false;
    }
}

extern "C" int32_t stateui_winui_picker_selected(StateUIObjectRef handle) {
    try {
        auto object = choicesOf(handle);
        if (auto bar = object.try_as<controls::SelectorBar>()) return chosenSegment(bar);
        if (auto radios = object.try_as<controls::RadioButtons>()) return radios.SelectedIndex();
        return object.as<controls::ComboBox>().SelectedIndex();
    } catch (...) {
        report("reading a picker's choice");
        return -1;
    }
}

extern "C" int32_t stateui_winui_picker_choices(StateUIObjectRef handle, char *utf8, int32_t capacity) {
    try {
        std::wstring joined;
        auto object = choicesOf(handle);
        auto join = [&](winrt::hstring const &words) {
            if (!joined.empty()) joined += L'\n';
            joined += words;
        };
        if (auto bar = object.try_as<controls::SelectorBar>()) {
            for (auto const &item : bar.Items()) join(item.Text());
        } else {
            auto items = object.try_as<controls::RadioButtons>() ? object.as<controls::RadioButtons>().Items()
                                                                 : object.as<controls::ComboBox>().Items();
            for (auto const &item : items) join(winrt::unbox_value_or<winrt::hstring>(item, L""));
        }
        auto words = winrt::to_string(joined);
        if (utf8 && capacity > 0) {
            auto count = std::min<size_t>(words.size(), static_cast<size_t>(capacity - 1));
            std::memcpy(utf8, words.data(), count);
            utf8[count] = 0;
        }
        return static_cast<int32_t>(words.size());
    } catch (...) {
        report("reading a picker's choices");
        return 0;
    }
}

extern "C" void stateui_winui_picker_open_as_user(StateUIObjectRef handle, bool open) {
    try {
        auto box = choicesOf(handle).try_as<controls::ComboBox>();
        if (!box) return;
        auto expanding = pattern<provider::IExpandCollapseProvider>(box, PatternInterface::ExpandCollapse);
        if (open) expanding.Expand();
        else expanding.Collapse();
    } catch (...) {
        report("opening a picker's list as the user");
    }
}

extern "C" void stateui_winui_picker_choose_as_user(StateUIObjectRef handle, int32_t index) {
    try {
        auto object = choicesOf(handle);
        if (auto bar = object.try_as<controls::SelectorBar>()) {
            if (index >= 0 && index < static_cast<int32_t>(bar.Items().Size())) bar.SelectedItem(bar.Items().GetAt(index));
        } else if (auto radios = object.try_as<controls::RadioButtons>()) {
            radios.SelectedIndex(index);
        } else {
            object.as<controls::ComboBox>().SelectedIndex(index);
        }
    } catch (...) {
        report("choosing in a picker as the user");
    }
}
