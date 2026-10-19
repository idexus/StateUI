// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A view's drags - its words carried away, words or files dropped on it - as WinUI's own drag and drop. Each handler
// names its view by number and holds nothing of the element it hangs on; it asks what the view offers as it runs.
// Design: docs/design/platforms/winui/input.md#a-drag-between-views

#include "Relay.h"

#include <unordered_map>

#include <winrt/Windows.ApplicationModel.DataTransfer.h>
#include <winrt/Windows.Storage.h>

using namespace stateui;
using winrt::Windows::Foundation::AsyncStatus;
using winrt::Windows::Foundation::IAsyncOperation;
using winrt::Windows::Foundation::Collections::IVectorView;
namespace transfer = winrt::Windows::ApplicationModel::DataTransfer;
namespace storage = winrt::Windows::Storage;

namespace {
    /// What a view offers and takes of a drag, and the element its handlers hang on - another stands in a password
    /// field's place.
    struct Offered {
        winrt::hstring words;
        bool draggable = false;
        bool takesWords = false;
        bool takesFiles = false;
        winrt::weak_ref<xaml::UIElement> hungOn;
    };

    std::unordered_map<int64_t, Offered> offered;

    Offered *offer(int64_t view) {
        auto found = offered.find(view);
        return found != offered.end() ? &found->second : nullptr;
    }

    /// Tells the host what the view heard of a drag, a drop with its words.
    void tell(int64_t view, StateUIDragHeard heard, std::string const &words = {}) {
        callbacks.dragHeard(view, heard, words.c_str());
    }

    /// Whether the drag carries what the view takes.
    bool taken(Offered const &entry, transfer::DataPackageView const &data) {
        return (entry.takesWords && data.Contains(transfer::StandardDataFormats::Text()))
            || (entry.takesFiles && data.Contains(transfer::StandardDataFormats::StorageItems()));
    }

    /// The files a drop holds, told on the UI thread by their paths and names.
    void tellFiles(int64_t view, std::vector<std::string> paths, std::vector<std::string> names) {
        runOnUIThread([view, paths = std::move(paths), names = std::move(names)] {
            std::vector<char const *> pathPointers, namePointers;
            for (auto const &path : paths) pathPointers.push_back(path.c_str());
            for (auto const &name : names) namePointers.push_back(name.c_str());
            callbacks.filesDragged(view, static_cast<int32_t>(paths.size()), pathPointers.data(), namePointers.data());
        });
    }

    /// Hangs every handler once.
    void hang(xaml::UIElement const &element, int64_t view) {
        element.DragStarting(guarded("handling DragStarting",
            [view](xaml::UIElement const &, xaml::DragStartingEventArgs const &args) {
            auto *entry = offer(view);
            if (!entry || !entry->draggable) return;
            args.Data().SetText(entry->words);
            args.Data().RequestedOperation(transfer::DataPackageOperation::Copy);
            tell(view, StateUIDragHeardStarted);
        }));
        element.DropCompleted(guarded("handling DropCompleted",
            [view](xaml::UIElement const &, xaml::DropCompletedEventArgs const &) {
            if (auto *entry = offer(view); entry && entry->draggable) tell(view, StateUIDragHeardEnded);
        }));
        auto over = [view](IInspectable const &, xaml::DragEventArgs const &args) {
            auto *entry = offer(view);
            if (!entry || !taken(*entry, args.DataView())) return;
            args.AcceptedOperation(transfer::DataPackageOperation::Copy);
            args.Handled(true);
            tell(view, StateUIDragHeardOver);
        };
        element.DragEnter(guarded("handling DragEnter", over));
        element.DragOver(guarded("handling DragOver", over));
        element.DragLeave(guarded("handling DragLeave", [view](IInspectable const &, xaml::DragEventArgs const &args) {
            auto *entry = offer(view);
            if (entry && taken(*entry, args.DataView())) tell(view, StateUIDragHeardLeft);
        }));
        element.Drop(guarded("handling Drop", [view](IInspectable const &, xaml::DragEventArgs const &args) {
            auto *entry = offer(view);
            auto data = args.DataView();
            if (!entry || !taken(*entry, data)) return;
            args.Handled(true);
            auto deferral = args.GetDeferral();
            if (entry->takesFiles && data.Contains(transfer::StandardDataFormats::StorageItems())) {
                data.GetStorageItemsAsync().Completed(guarded("handling a drop's files", [view, deferral](
                    IAsyncOperation<IVectorView<storage::IStorageItem>> const &found, AsyncStatus status) {
                    std::vector<std::string> paths, names;
                    if (status == AsyncStatus::Completed) {
                        for (auto const &item : found.GetResults()) {
                            paths.push_back(winrt::to_string(item.Path()));
                            names.push_back(winrt::to_string(item.Name()));
                        }
                    }
                    deferral.Complete();
                    tellFiles(view, std::move(paths), std::move(names));
                }));
                return;
            }
            data.GetTextAsync().Completed(guarded("handling a drop's words", [view, deferral](
                IAsyncOperation<winrt::hstring> const &text, AsyncStatus status) {
                auto words = status == AsyncStatus::Completed ? winrt::to_string(text.GetResults()) : std::string{};
                deferral.Complete();
                runOnUIThread([view, words] { tell(view, StateUIDragHeardDropped, words); });
            }));
        }));
    }
}

extern "C" void stateui_winui_offer_drag(
    StateUIObjectRef handle, int64_t view, char const *words, bool takesWords, bool takesFiles) {
    try {
        auto element = as<xaml::UIElement>(handle);
        element.CanDrag(words != nullptr);
        element.AllowDrop(takesWords || takesFiles);
        // A view offering nothing - one that left among them - is forgotten; its handlers find nothing of it.
        if (!words && !takesWords && !takesFiles) {
            offered.erase(view);
            return;
        }
        auto &entry = offered[view];
        entry.draggable = words != nullptr;
        entry.words = words ? winrt::to_hstring(words) : winrt::hstring{};
        entry.takesWords = takesWords;
        entry.takesFiles = takesFiles;
        if (entry.hungOn.get() != element) {
            hang(element, view);
            entry.hungOn = winrt::make_weak(element);
        }
    } catch (...) {
        report("offering a drag");
    }
}

extern "C" void stateui_winui_drag_read(StateUIObjectRef handle, bool *canDrag, bool *allowsDrop) {
    try {
        auto element = as<xaml::UIElement>(handle);
        *canDrag = element.CanDrag();
        *allowsDrop = element.AllowDrop();
    } catch (...) {
        report("reading a drag");
    }
}

extern "C" int32_t stateui_winui_drag_offers() {
    try {
        return static_cast<int32_t>(offered.size());
    } catch (...) {
        report("counting the drag offers");
        return 0;
    }
}
