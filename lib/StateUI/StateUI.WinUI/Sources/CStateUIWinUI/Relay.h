// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the relay's files share: the projection, the host's callbacks, and the
// three ways a handle crosses. No C++ exception leaves a function of the relay.
// Design: docs/design/platforms/winui/relay.md#the-c-surface
#pragma once

#define NOMINMAX
#include <windows.h>
#include <unknwn.h>
// winbase.h's macro would rewrite a WinRT method of the same name.
#undef GetCurrentTime

#include <cstdio>
#include <functional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.Numerics.h>
#include <winrt/Microsoft.UI.Xaml.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Controls.Primitives.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

#include "CStateUIWinUI.h"

namespace stateui {
    namespace xaml = winrt::Microsoft::UI::Xaml;
    namespace controls = winrt::Microsoft::UI::Xaml::Controls;
    using winrt::Windows::Foundation::IInspectable;

    /// The host's callbacks, set by run or embed.
    extern StateUIWinUICallbacks callbacks;

    /// Runs `work` on the UI thread, in its turn; from any thread.
    void post(void (*work)());

    /// Runs `work` on the UI thread, in its turn; from any thread - what a WinRT operation ending beside it hands back.
    void runOnUIThread(std::function<void()> work);

    /// The color `argb` - 0xAARRGGBB - is.
    inline winrt::Windows::UI::Color color(uint32_t argb) {
        return {static_cast<uint8_t>(argb >> 24), static_cast<uint8_t>(argb >> 16), static_cast<uint8_t>(argb >> 8),
                static_cast<uint8_t>(argb)};
    }

    /// WinUI's own brush for a brush as the host hands it; null for none.
    xaml::Media::Brush brush(StateUIBrush const &brush);

    /// The brush of a ground: null for WinUI's own, a color `argb`, or the in-app acrylic in it - its luminosity
    /// hiding `opacity` of what is behind it and its tint `tintOpacity`.
    xaml::Media::Brush ground(StateUIGround kind, uint32_t argb, float opacity, float tintOpacity);

    /// A brush painting an oval `width` by `height`: `fill`'s first color keeping `share` of its opacity inside,
    /// `stroke`'s first color `lineWidth` wide inside its edge.
    xaml::Media::Brush oval(StateUIBrush const &fill, StateUIBrush const &stroke, double lineWidth, double share,
                            double width, double height);

    /// WinUI's accelerator for `key` and `modifiers` - a VirtualKey and VirtualKeyModifiers - which invokes its
    /// owner while its window is in front; one giving way to typing invokes nothing while a field the user types
    /// into holds the keyboard.
    xaml::Input::KeyboardAccelerator accelerator(int32_t key, int32_t modifiers, bool givesWayToTyping);

    /// The words WinUI shows beside an item for an accelerator - `Ctrl+Shift+S`.
    winrt::hstring acceleratorText(int32_t key, int32_t modifiers);

    /// Whether the view numbered `view` listens for taps; and a press assistive technology made on it, told as
    /// a tap.
    bool hearsTaps(int64_t view);
    void press(int64_t view);

    /// Whether the keyboard's focus is on `element` or on what stands in it.
    bool holdsFocus(xaml::UIElement const &element);

    /// Writes `brushes` into the control's own resources under the names its template reads - lightweight styling;
    /// a null brush takes its name away. A solid brush standing there takes the new color in place, which what it
    /// paints follows; one that comes, goes or is of another kind has the control's theme read again, as its template
    /// takes such a resource only then.
    /// Design: docs/design/platforms/winui/controls.md#a-controls-accent
    void writeResources(xaml::FrameworkElement const &control,
                        std::vector<std::pair<std::wstring, xaml::Media::Brush>> const &brushes);

    /// Reads the control's theme again, so its template takes the resources written into it and its parents.
    void readThemeAgain(xaml::FrameworkElement const &control);

    /// The brush `resources` itself holds under `name`; null for none. `HasKey` and `Lookup` look on into the
    /// application's theme, whose brushes every control shares: only a walk of the dictionary finds its own.
    xaml::Media::Brush ownBrush(xaml::ResourceDictionary const &resources, std::wstring const &name);

    /// The words a label shows - the text block its border holds - or `element` itself where it is a text block;
    /// null for any other element.
    controls::TextBlock wordsOf(IInspectable const &element);

    /// The text block of the label `handle` names; throws for any other element.
    controls::TextBlock labelWords(StateUIObjectRef handle);

    /// The words a button shows: its content, or the text block beside its picture; null for none, and for any
    /// other element.
    controls::TextBlock captionOf(IInspectable const &element);

    /// What assistive technology meets of an element: a label's words, a picture's image or icon, or the element itself.
    xaml::UIElement metOf(IInspectable const &element);

    /// The first of the files `names` - UTF-8, each ended by a line feed - that the application's pictures hold;
    /// empty for none.
    std::wstring pictureFile(char const *names);

    /// A source reading the application's picture `file` - a bitmap, or an SVG - from its address, at its own
    /// proportions.
    xaml::Media::ImageSource pictureSource(std::wstring const &file);

    /// The name of what `names` asks to show - the file found, an icon's `glyph:`, the bytes' count and sum - by
    /// which a picture shown is told from another (`iconFile`, `sourceFile`, `shownName`); empty for none.
    std::wstring pictureName(char const *names);

    /// An icon showing what `names` asks: a FontIcon's glyph, or the first of the files the pictures hold, or
    /// bytes, as an ImageIcon (`iconFile`); null for none.
    controls::IconElement pictureIcon(char const *names);

    /// What shows that picture at its own size: a FontIcon for an icon, an image for a file - an SVG at the size
    /// it declares, which WinUI takes for thousands of pixels - or bytes (`shownName`); null for none.
    xaml::FrameworkElement pictureImage(char const *names);

    /// An icon source showing what `names` asks, as `pictureIcon` does (`sourceFile`); null for none.
    controls::IconSource pictureIconSource(char const *names);

    /// The name of the picture `pictureImage` or `pictureIcon` made `shown` with; empty for any other.
    std::wstring shownName(xaml::UIElement const &shown);

    /// The file an icon source `pictureIconSource` made shows; empty for any other, and for none.
    std::wstring sourceFile(controls::IconSource const &icon);

    /// The file `source` reads by its address; empty for one read from memory.
    std::wstring sourceFile(xaml::Media::ImageSource const &source);

    /// The file an icon `pictureIcon` made shows; empty for any other icon, and for none.
    std::wstring iconFile(controls::IconElement const &icon);

    /// Names `brushes` - a name a template reads, a color - in the entry's resources for the light theme and the dark,
    /// before the entry stands. Design: docs/design/platforms/winui/pages.md#a-bars-buttons
    void nameThemedBrushes(
        xaml::FrameworkElement const &entry, std::vector<std::pair<std::wstring, std::wstring>> const &brushes);

    /// Whether the entry's own theme dictionaries name a brush `name`.
    bool namesThemedBrush(xaml::FrameworkElement const &entry, wchar_t const *name);

    /// Marks an entry whose choice destroys something: its words' brushes `names` - at rest, under the pointer and
    /// pressed - take the theme's critical color, light or dark as the entry's own theme is. Written before the
    /// entry stands, as its template reads them then.
    /// Design: docs/design/platforms/winui/pages.md#a-destructive-entry
    void markDestructive(xaml::FrameworkElement const &entry, std::vector<std::wstring> const &names);

    /// Whether the entry is marked so: its own theme dictionaries name its words' brush `name`.
    bool isDestructive(xaml::FrameworkElement const &entry, wchar_t const *name);

    /// Paints a panel clear while its view listens for the user or offers a context menu, so it is hit across its
    /// bounds and not only where its children stand; takes that away once neither holds. An author's background
    /// stays.
    void holdHitArea(xaml::UIElement const &element, int64_t view);

    /// The theme an element is asked to stand in for `scheme`, a `StateUIColorScheme`; and the scheme of a theme.
    xaml::ElementTheme elementTheme(int32_t scheme);
    int32_t colorScheme(xaml::ElementTheme theme);

    /// WinUI's input scope the relay numbers `scope` (`WinUIInputScope`): the on-screen keyboard a field brings up.
    xaml::Input::InputScope inputScope(int32_t scope);

    /// Keeps what the screen reader was told, which a test reads back (`stateui_winui_announced`).
    void announced(std::string const &words);

    /// Keeps what was handed to Windows to launch, which a test reads back (`stateui_winui_launched`).
    void launched(std::string const &target);

    /// The file dialog showing in the process, and the field its file's name is typed in; null for none.
    HWND fileDialog();
    HWND fileNameField(HWND dialog);

    /// Says on standard error, where the host's log goes, what failed and why - the exception being handled,
    /// WinUI's, the standard library's or any other - so that none crosses the C boundary; answers its code, WinUI's
    /// own or `E_FAIL`. Called only inside a `catch (...)`.
    inline int32_t report(char const *where) {
        int32_t code = E_FAIL;
        std::string words;
        try {
            throw;
        } catch (winrt::hresult_error const &error) {
            code = error.code();
            words = winrt::to_string(error.message());
        } catch (std::exception const &error) {
            words = error.what();
        } catch (...) {
            words = "an exception of no kind known";
        }
        // As UTF-8: `%ls` stops at the first letter outside ASCII, the rest of the line with it.
        std::fprintf(stderr, "StateUI WinUI: %s failed: 0x%08x %s\n", where, static_cast<unsigned>(code), words.c_str());
        std::fflush(stderr);
        return code;
    }

    /// A handler WinUI calls from its own loop, what it throws said and swallowed: one leaving it is stowed and ends
    /// the process.
    template <typename Handler>
    auto guarded(char const *where, Handler handler) {
        return [where, handler = std::move(handler)](auto &&...arguments) mutable {
            try {
                handler(std::forward<decltype(arguments)>(arguments)...);
            } catch (...) {
                report(where);
            }
        };
    }

    /// `member` of `object` as a guarded handler, called while the object lives: the handler holds it weakly.
    template <typename Object, typename Member>
    auto guarded(char const *where, winrt::weak_ref<Object> object, Member member) {
        return guarded(where, [object = std::move(object), member](auto &&...arguments) {
            if (auto strong = object.get()) (strong.get()->*member)(std::forward<decltype(arguments)>(arguments)...);
        });
    }

    /// Hands a projected object's default interface to the host, AddRef'd.
    template <typename T>
    StateUIObjectRef detach(T object) {
        return static_cast<StateUIObjectRef>(winrt::detach_abi(object));
    }

    /// The object a handle holds, as the type it was made as: no QueryInterface.
    template <typename T>
    T borrow(StateUIObjectRef handle) {
        T object{nullptr};
        winrt::copy_from_abi(object, handle);
        return object;
    }

    /// The object a handle holds, as any of its interfaces: one QueryInterface.
    template <typename T>
    T as(StateUIObjectRef handle) {
        IInspectable object{nullptr};
        winrt::copy_from_abi(object, handle);
        return object.as<T>();
    }

    /// UTF-8 from the host as WinRT's string.
    inline winrt::hstring text(char const *utf8) {
        return winrt::to_hstring(std::string_view(utf8 ? utf8 : ""));
    }

    /// A grid of rows, each given its height: `Auto` for one sized to what stands in it, a star for the rest.
    inline controls::Grid rows(std::initializer_list<bool> automatic) {
        controls::Grid grid;
        for (bool sized : automatic) {
            controls::RowDefinition row;
            row.Height(sized ? xaml::GridLengthHelper::Auto() : xaml::GridLengthHelper::FromValueAndType(1, xaml::GridUnitType::Star));
            grid.RowDefinitions().Append(row);
        }
        return grid;
    }

    /// The first element of type `T` in `element`'s tree, depth first, named `name` where one is given - a part of a
    /// control's template among them; null for none.
    template <typename T>
    T first(xaml::DependencyObject const &element, wchar_t const *name = nullptr) {
        auto count = xaml::Media::VisualTreeHelper::GetChildrenCount(element);
        for (int32_t index = 0; index < count; ++index) {
            auto child = xaml::Media::VisualTreeHelper::GetChild(element, index);
            auto found = child.try_as<T>();
            if (found && (!name || child.as<xaml::FrameworkElement>().Name() == name)) return found;
            if (auto inner = first<T>(child, name)) return inner;
        }
        return nullptr;
    }

    /// The command bar holding the page's actions at a title bar's leading edge, and the one at its trailing edge.
    inline controls::CommandBar leadingActions(controls::TitleBar const &bar) {
        return bar.LeftHeader().as<controls::CommandBar>();
    }
    inline controls::CommandBar trailingActions(controls::TitleBar const &bar) {
        return bar.RightHeader().as<controls::CommandBar>();
    }

    /// The two command bars a bar's actions stand on: its leading edge's, and its trailing edge's with "more" behind
    /// it - a title bar's headers, or the head of a sheet.
    struct ActionEdges {
        controls::CommandBar leading{nullptr};
        controls::CommandBar trailing{nullptr};
    };

    /// A title bar's edges.
    inline ActionEdges actionEdges(controls::TitleBar const &bar) {
        return {leadingActions(bar), trailingActions(bar)};
    }

    /// The edges of a sheet's head, beside its title.
    ActionEdges sheetActionEdges(controls::Grid const &sheet);

    /// The edges of the head of a split view's pane, over its sidebar page.
    ActionEdges paneActionEdges(controls::SplitView const &split);

    /// Paints the actions on `edges` and "more" in `foreground`, or the theme's where it is null; a destructive one
    /// keeps the theme's critical color.
    void paintActions(ActionEdges const &edges, xaml::Media::Brush const &foreground);

    /// A command bar for the actions at one of a bar's edges, on the bar's own background.
    inline controls::CommandBar actionBar() {
        controls::CommandBar actions;
        actions.DefaultLabelPosition(controls::CommandBarDefaultLabelPosition::Right);
        actions.Background(xaml::Media::SolidColorBrush(winrt::Windows::UI::Color{0, 0, 0, 0}));
        actions.VerticalAlignment(xaml::VerticalAlignment::Center);
        return actions;
    }

    /// Puts `count` actions on `edges`, as `stateui_winui_title_bar_set_actions` says; `owner` is the element whose
    /// theme fades a disabled picture, `view` the one a press is told to.
    void setActions(
        ActionEdges const &edges, xaml::FrameworkElement const &owner, int64_t view, char const *const *texts,
        char const *const *identifiers, char const *const *icons, bool const *words, bool const *destructive,
        int32_t const *groups, int32_t leadingGroups, bool const *enabled, int32_t const *keys,
        int32_t const *modifiers, bool const *givesWay, int32_t const *states, int32_t const *openings, int32_t count);

    /// Gives the action at `place` on `edges` its menu, as `stateui_winui_title_bar_set_action_menu` says.
    void setActionMenu(
        ActionEdges const &edges, int64_t view, int32_t place, bool held, int32_t first, int32_t const *kinds,
        char const *const *titles, bool const *enabled, char const *const *identifiers, char const *const *icons,
        bool const *destructive, int32_t const *keys, int32_t const *modifiers, bool const *givesWay, int32_t count);

    /// Whether `element` is one of a window's layers over its rows - its sheets or its overlays - and no row's own.
    inline bool isLayer(xaml::FrameworkElement const &element) {
        auto name = winrt::unbox_value_or<winrt::hstring>(element.Tag(), L"");
        return name == L"sheets" || name == L"overlay";
    }

    /// Stands `element` in `row` of `grid` in place of what stood there; nothing for null.
    inline void standInRow(controls::Grid const &grid, int32_t row, StateUIObjectRef element) {
        auto children = grid.Children();
        auto next = element ? as<xaml::FrameworkElement>(element) : xaml::FrameworkElement{nullptr};
        for (uint32_t index = children.Size(); index-- > 0;) {
            auto child = children.GetAt(index).as<xaml::FrameworkElement>();
            if (isLayer(child) || controls::Grid::GetRow(child) != row) continue;
            if (child == next) return;
            children.RemoveAt(index);
        }
        if (!next) return;
        controls::Grid::SetRow(next, row);
        children.Append(next);
    }
}
