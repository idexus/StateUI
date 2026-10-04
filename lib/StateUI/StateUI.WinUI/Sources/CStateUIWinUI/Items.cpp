// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An ItemsView: WinUI's ItemsView over the identities the host gives it. Each
// entry's cell is a panel the host holds the entry in, stood in an
// ItemContainer the relay keeps for the list's life; what the host says waits
// while the list lays its cells out.
// Design: docs/design/platforms/winui/items.md

#include "Relay.h"

#include <winrt/Microsoft.UI.Dispatching.h>
#include <winrt/Microsoft.UI.Xaml.Automation.Peers.h>
#include <winrt/Microsoft.UI.Xaml.Automation.Provider.h>

#include <algorithm>
#include <cstring>
#include <deque>
#include <functional>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

using namespace stateui;

namespace peers = winrt::Microsoft::UI::Xaml::Automation::Peers;
namespace provider = winrt::Microsoft::UI::Xaml::Automation::Provider;

namespace {
    void tellShowing(controls::ItemsView const &list, int64_t view);

    /// What the relay keeps of one ItemsView, and the factory its cells come from.
    struct Cells : winrt::implements<Cells, xaml::IElementFactory> {
        explicit Cells(int64_t view) : view(view) {}

        int64_t view;

        /// The list the cells stand in.
        winrt::weak_ref<controls::ItemsView> list;

        winrt::Windows::Foundation::Collections::IObservableVector<IInspectable> source =
            winrt::single_threaded_observable_vector<IInspectable>();

        /// Each identity's kind: an item (0), or a header or a footer (1).
        std::unordered_map<std::wstring, int32_t> kinds;

        /// Every container made, by its interface, with its panel's number and its kind; and those put aside.
        struct Made {
            int64_t number;
            int32_t kind;
            winrt::weak_ref<controls::ItemContainer> container;
        };
        std::unordered_map<void *, Made> made;
        std::vector<controls::ItemContainer> aside[2];

        /// How the entries stand: down (0), across (1) or in columns (2).
        int32_t shape = 0;

        /// Whether the program is choosing, which the user's choice is not told of.
        bool choosing = false;

        /// How deep the list is in asking for cells, and what waits for it to be done.
        int32_t laying = 0;
        std::deque<std::function<void()>> waiting;
        bool draining = false;
        bool released = false;

        /// The wait for the layout of cells just asked for or put aside, after which what stands in view is told.
        winrt::event_token laidOut{};

        xaml::UIElement GetElement(xaml::ElementFactoryGetArgs const &args) {
            try {
                auto identity = winrt::unbox_value_or<winrt::hstring>(args.Data(), L"");
                auto found = kinds.find(std::wstring(identity));
                auto kind = found == kinds.end() ? 0 : found->second;
                ++laying;
                controls::ItemContainer container{nullptr};
                if (!aside[kind].empty()) {
                    container = aside[kind].back();
                    aside[kind].pop_back();
                } else {
                    container = make(kind);
                }
                if (!released) {
                    callbacks.itemHeld(view, made[winrt::get_abi(container)].number, winrt::to_string(identity).c_str());
                }
                --laying;
                drainLater();
                tellWhenLaidOut();
                return container;
            } catch (...) {
                --laying;
                report("making an ItemsView's cell");
                return controls::ItemContainer{};
            }
        }

        void RecycleElement(xaml::ElementFactoryRecycleArgs const &args) {
            try {
                auto container = args.Element().try_as<controls::ItemContainer>();
                if (!container || released) return;
                auto found = made.find(winrt::get_abi(container));
                if (found == made.end()) return;
                ++laying;
                if (!released) callbacks.itemLetGo(view, found->second.number);
                --laying;
                aside[found->second.kind].push_back(container);
                drainLater();
                tellWhenLaidOut();
            } catch (...) {
                report("putting an ItemsView's cell aside");
            }
        }

        /// A container around a new panel of the host's.
        controls::ItemContainer make(int32_t kind) {
            int64_t number = 0;
            auto panel = callbacks.itemCell(view, kind, &number);
            controls::ItemContainer container;
            if (panel) container.Child(as<xaml::UIElement>(panel));
            made[winrt::get_abi(container)] = {number, kind, container};
            return container;
        }

        /// Tells what stands in view once the list has laid out the cells it asked for or put aside: what the view
        /// shows changed, where its scroller may say nothing - a view brought back within an extent cut short.
        void tellWhenLaidOut() {
            if (laidOut || released) return;
            auto owner = list.get();
            if (!owner) return;
            laidOut = owner.LayoutUpdated(guarded("handling LayoutUpdated",
                [weak = get_weak()](IInspectable const &, IInspectable const &) {
                auto self = weak.get();
                if (!self) return;
                auto owner = self->list.get();
                auto token = std::exchange(self->laidOut, {});
                if (!owner) return;
                owner.LayoutUpdated(token);
                if (!self->released) tellShowing(owner, self->view);
            }));
        }

        /// The container holding the cell numbered `number`; null where there is none.
        controls::ItemContainer holding(int64_t number) {
            for (auto const &[_, each] : made) {
                if (each.number == number) return each.container.get();
            }
            return nullptr;
        }

        /// Runs `apply` now, or once the list is done asking for cells, after everything waiting before it.
        void change(std::function<void()> apply) {
            if (laying == 0 && waiting.empty()) {
                apply();
                return;
            }
            waiting.push_back(std::move(apply));
            drainLater();
        }

        void drainLater() {
            if (laying > 0 || waiting.empty() || draining) return;
            draining = true;
            auto self = get_strong();
            auto queue = winrt::Microsoft::UI::Dispatching::DispatcherQueue::GetForCurrentThread();
            queue.TryEnqueue(guarded("handling TryEnqueue", [self] {
                self->draining = false;
                while (!self->waiting.empty() && self->laying == 0) {
                    auto next = std::move(self->waiting.front());
                    self->waiting.pop_front();
                    next();
                }
            }));
        }
    };

    winrt::com_ptr<Cells> cellsOf(controls::ItemsView const &list) {
        winrt::com_ptr<Cells> cells;
        cells.copy_from(winrt::get_self<Cells>(list.ItemTemplate()));
        return cells;
    }

    std::wstring identity(IInspectable const &item) {
        return std::wstring(winrt::unbox_value_or<winrt::hstring>(item, L""));
    }

    /// Tells the host the places of the first and the last entry in view, where WinUI has laid them out.
    void tellShowing(controls::ItemsView const &list, int64_t view) {
        int32_t first = -1;
        int32_t last = -1;
        if (!list.TryGetItemIndex(0.0, 0.0, first) || !list.TryGetItemIndex(1.0, 1.0, last)) return;
        if (first >= 0 && last >= first) callbacks.itemsShowing(view, first, last);
    }

    /// The scroller moves across for a row, down otherwise, and tells what stands in view as it moves.
    void standScroller(controls::ItemsView const &list, int32_t shape) {
        auto scroller = list.ScrollView();
        if (!scroller) return;
        scroller.ContentOrientation(
            shape == 1 ? controls::ScrollingContentOrientation::Horizontal : controls::ScrollingContentOrientation::Vertical);
    }
}

extern "C" StateUIObjectRef stateui_winui_items_make(int64_t view) {
    try {
        controls::ItemsView list;
        auto cells = winrt::make_self<Cells>(view);
        cells->list = list;
        list.ItemTemplate(cells.as<xaml::IElementFactory>());
        list.ItemsSource(cells->source);
        list.SelectionMode(controls::ItemsViewSelectionMode::None);
        list.SelectionChanged(guarded("handling SelectionChanged",
            [view](controls::ItemsView const &sender, controls::ItemsViewSelectionChangedEventArgs const &) {
            if (cellsOf(sender)->choosing) return;
            std::wstring joined;
            for (auto const &item : sender.SelectedItems()) {
                if (!joined.empty()) joined += L'\n';
                joined += identity(item);
            }
            callbacks.itemsChose(view, winrt::to_string(joined).c_str());
        }));
        list.ItemInvoked(guarded("handling ItemInvoked",
            [view](controls::ItemsView const &, controls::ItemsViewItemInvokedEventArgs const &args) {
            callbacks.itemInvoked(view, winrt::to_string(identity(args.InvokedItem())).c_str());
        }));
        list.Loaded(guarded("handling Loaded", [view](IInspectable const &sender, xaml::RoutedEventArgs const &) {
            auto list = sender.as<controls::ItemsView>();
            standScroller(list, cellsOf(list)->shape);
            if (auto scroller = list.ScrollView()) {
                winrt::weak_ref<controls::ItemsView> weak = list;
                scroller.ViewChanged(guarded("handling ViewChanged",
                    [weak, view](controls::ScrollView const &, IInspectable const &) {
                    if (auto list = weak.get()) tellShowing(list, view);
                }));
                // Entries changed stand in view once laid out, where the view may not move at all.
                scroller.ExtentChanged(guarded("handling ExtentChanged",
                    [weak, view](controls::ScrollView const &, IInspectable const &) {
                    if (auto list = weak.get()) tellShowing(list, view);
                }));
            }
            tellShowing(list, view);
        }));
        return detach(list);
    } catch (...) {
        report("making an ItemsView");
        return nullptr;
    }
}

extern "C" void stateui_winui_items_set_entries(
    StateUIObjectRef handle, char const *const *identities, int32_t const *kinds, int32_t count,
    int32_t const *removed, int32_t removedCount, int32_t const *inserted, int32_t insertedCount
) {
    try {
        auto list = borrow<controls::ItemsView>(handle);
        auto cells = cellsOf(list);
        std::vector<winrt::hstring> names;
        std::vector<int32_t> sorts(kinds, kinds + count);
        for (int32_t index = 0; index < count; ++index) names.push_back(text(identities[index]));
        std::vector<int32_t> removals(removed, removed + removedCount);
        std::vector<int32_t> insertions(inserted, inserted + insertedCount);
        cells->change([cells, names, sorts, removals, insertions] {
            cells->kinds.clear();
            for (size_t index = 0; index < names.size(); ++index) cells->kinds[std::wstring(names[index])] = sorts[index];
            for (size_t run = 0; run + 1 < removals.size(); run += 2) {
                for (int32_t each = 0; each < removals[run + 1]; ++each) cells->source.RemoveAt(removals[run]);
            }
            for (size_t run = 0; run + 1 < insertions.size(); run += 2) {
                for (int32_t each = 0; each < insertions[run + 1]; ++each) {
                    auto place = insertions[run] + each;
                    cells->source.InsertAt(place, winrt::box_value(names[place]));
                }
            }
        });
    } catch (...) {
        report("setting an ItemsView's entries");
    }
}

extern "C" void stateui_winui_items_set_layout(
    StateUIObjectRef handle, int32_t shape, double spacing, double minimumItemWidth
) {
    try {
        auto list = borrow<controls::ItemsView>(handle);
        auto cells = cellsOf(list);
        winrt::weak_ref<controls::ItemsView> weak = list;
        cells->change([cells, weak, shape, spacing, minimumItemWidth] {
            auto list = weak.get();
            if (!list) return;
            cells->shape = shape;
            if (shape == 2) {
                controls::UniformGridLayout grid;
                grid.MinItemWidth(minimumItemWidth);
                grid.MinColumnSpacing(spacing);
                grid.MinRowSpacing(spacing);
                grid.ItemsStretch(controls::UniformGridLayoutItemsStretch::Fill);
                list.Layout(grid);
            } else {
                controls::StackLayout stack;
                stack.Orientation(shape == 1 ? controls::Orientation::Horizontal : controls::Orientation::Vertical);
                stack.Spacing(spacing);
                list.Layout(stack);
            }
            standScroller(list, shape);
        });
    } catch (...) {
        report("setting an ItemsView's layout");
    }
}

extern "C" void stateui_winui_items_set_choice(
    StateUIObjectRef handle, int32_t mode, char const *const *chosen, int32_t count, bool invokable
) {
    try {
        auto list = borrow<controls::ItemsView>(handle);
        auto cells = cellsOf(list);
        std::unordered_set<std::wstring> wanted;
        for (int32_t index = 0; index < count; ++index) wanted.insert(std::wstring(text(chosen[index])));
        winrt::weak_ref<controls::ItemsView> weak = list;
        cells->change([cells, weak, mode, wanted, invokable] {
            auto list = weak.get();
            if (!list) return;
            cells->choosing = true;
            list.SelectionMode(
                mode == 2 ? controls::ItemsViewSelectionMode::Multiple
                    : mode == 1 ? controls::ItemsViewSelectionMode::Single : controls::ItemsViewSelectionMode::None);
            list.IsItemInvokedEnabled(invokable);
            for (uint32_t place = 0; place < cells->source.Size(); ++place) {
                auto want = wanted.count(identity(cells->source.GetAt(place))) > 0;
                auto index = static_cast<int32_t>(place);
                if (want != list.IsSelected(index)) {
                    if (want) list.Select(index); else list.Deselect(index);
                }
            }
            cells->choosing = false;
        });
    } catch (...) {
        report("setting an ItemsView's choice");
    }
}

extern "C" void stateui_winui_items_scroll_to(StateUIObjectRef handle, int32_t index, int32_t anchor, bool animated) {
    try {
        auto list = borrow<controls::ItemsView>(handle);
        auto cells = cellsOf(list);
        winrt::weak_ref<controls::ItemsView> weak = list;
        cells->change([cells, weak, index, anchor, animated] {
            auto list = weak.get();
            if (!list) return;
            xaml::BringIntoViewOptions options;
            options.AnimationDesired(animated);
            // Nearest leaves the ratios unset: WinUI then moves the item only as far as brings it wholly into view.
            if (anchor != 3) {
                auto ratio = anchor == 0 ? 0.0 : anchor == 1 ? 0.5 : 1.0;
                if (cells->shape == 1) options.HorizontalAlignmentRatio(ratio); else options.VerticalAlignmentRatio(ratio);
            }
            list.StartBringItemIntoView(index, options);
        });
    } catch (...) {
        report("scrolling an ItemsView to an item");
    }
}

extern "C" void stateui_winui_items_release(StateUIObjectRef handle) {
    try {
        auto list = borrow<controls::ItemsView>(handle);
        auto cells = cellsOf(list);
        cells->released = true;
        cells->waiting.clear();
        list.ItemsSource(nullptr);
        // A container refuses to hold nothing: each is let go of whole, and its panel with it.
        for (auto &kind : cells->aside) kind.clear();
        cells->made.clear();
    } catch (...) {
        report("releasing an ItemsView");
    }
}

extern "C" int32_t stateui_winui_items_chosen(StateUIObjectRef handle, char *utf8, int32_t capacity) {
    try {
        std::wstring joined;
        for (auto const &item : borrow<controls::ItemsView>(handle).SelectedItems()) {
            if (!joined.empty()) joined += L'\n';
            joined += identity(item);
        }
        auto words = winrt::to_string(joined);
        if (utf8 && capacity > 0) {
            auto count = std::min<size_t>(words.size(), static_cast<size_t>(capacity - 1));
            std::memcpy(utf8, words.data(), count);
            utf8[count] = 0;
        }
        return static_cast<int32_t>(words.size());
    } catch (...) {
        report("reading an ItemsView's choice");
        return 0;
    }
}

extern "C" int32_t stateui_winui_items_mode(StateUIObjectRef handle) {
    try {
        switch (borrow<controls::ItemsView>(handle).SelectionMode()) {
        case controls::ItemsViewSelectionMode::Single: return 1;
        case controls::ItemsViewSelectionMode::Multiple: return 2;
        default: return 0;
        }
    } catch (...) {
        report("reading an ItemsView's mode");
        return 0;
    }
}

extern "C" void stateui_winui_items_choose_as_user(StateUIObjectRef handle, int32_t index) {
    try {
        auto list = borrow<controls::ItemsView>(handle);
        if (list.SelectionMode() == controls::ItemsViewSelectionMode::Multiple && list.IsSelected(index)) {
            list.Deselect(index);
        } else {
            list.Select(index);
        }
    } catch (...) {
        report("choosing an item as the user");
    }
}

extern "C" bool stateui_winui_items_invoke_as_user(StateUIObjectRef cell) {
    try {
        xaml::DependencyObject step = as<xaml::UIElement>(cell);
        while (step && !step.try_as<controls::ItemContainer>()) step = xaml::Media::VisualTreeHelper::GetParent(step);
        if (!step) return false;
        auto peer = peers::FrameworkElementAutomationPeer::CreatePeerForElement(step.as<xaml::UIElement>());
        auto pattern = peer ? peer.GetPattern(peers::PatternInterface::Invoke) : nullptr;
        auto invoke = pattern ? pattern.try_as<provider::IInvokeProvider>() : nullptr;
        if (!invoke) return false;
        invoke.Invoke();
        return true;
    } catch (...) {
        report("opening an item as the user");
        return false;
    }
}

extern "C" void stateui_winui_items_scroll_as_user(StateUIObjectRef handle, double x, double y) {
    try {
        auto scroller = borrow<controls::ItemsView>(handle).ScrollView();
        if (!scroller) return;
        scroller.ScrollTo(x, y, controls::ScrollingScrollOptions(controls::ScrollingAnimationMode::Disabled));
    } catch (...) {
        report("scrolling an ItemsView as the user");
    }
}

extern "C" void stateui_winui_items_offset(StateUIObjectRef handle, double *offset) {
    offset[0] = offset[1] = offset[2] = offset[3] = 0;
    try {
        auto scroller = borrow<controls::ItemsView>(handle).ScrollView();
        if (!scroller) return;
        offset[0] = scroller.HorizontalOffset();
        offset[1] = scroller.VerticalOffset();
        offset[2] = scroller.ScrollableWidth();
        offset[3] = scroller.ScrollableHeight();
    } catch (...) {
        report("reading an ItemsView's view");
    }
}

extern "C" void stateui_winui_items_name(StateUIObjectRef handle, int64_t cell, char const *words) {
    try {
        auto container = cellsOf(borrow<controls::ItemsView>(handle))->holding(cell);
        if (container) xaml::Automation::AutomationProperties::SetName(container, text(words));
    } catch (...) {
        report("naming an ItemsView's row");
    }
}

extern "C" int32_t stateui_winui_items_row_name(StateUIObjectRef handle, int64_t cell, char *utf8, int32_t capacity) {
    try {
        auto container = cellsOf(borrow<controls::ItemsView>(handle))->holding(cell);
        auto peer = container ? peers::FrameworkElementAutomationPeer::CreatePeerForElement(container) : nullptr;
        auto words = peer ? winrt::to_string(peer.GetName()) : std::string();
        if (utf8 && capacity > 0) {
            auto count = std::min<size_t>(words.size(), static_cast<size_t>(capacity - 1));
            std::memcpy(utf8, words.data(), count);
            utf8[count] = 0;
        }
        return static_cast<int32_t>(words.size());
    } catch (...) {
        report("reading an ItemsView's row name");
        return 0;
    }
}
