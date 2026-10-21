// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Pictures from the application's own folder: an Image showing one by file
// name, an SVG found under the PNG name it is asked for, at the size it
// declares, drawn at the size it shows at - one source a file and a size.
// A picture's own bytes are read from memory; an icon is a FontIcon's glyph.
// Design: docs/design/platforms/winui/controls.md#pictures

#include "Relay.h"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <functional>
#include <map>
#include <string>
#include <tuple>
#include <vector>

#include <shcore.h>
#include <shlwapi.h>

#include <winrt/Microsoft.UI.Xaml.Automation.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Microsoft.UI.Xaml.Media.Imaging.h>

using namespace stateui;
namespace imaging = winrt::Microsoft::UI::Xaml::Media::Imaging;

namespace {
    /// The folder pictures are read from; empty for `Images` beside the executable.
    std::wstring folder;

    std::wstring pictures() {
        if (!folder.empty()) return folder;
        wchar_t path[MAX_PATH] = {};
        GetModuleFileNameW(nullptr, path, MAX_PATH);
        std::wstring executable(path);
        return executable.substr(0, executable.find_last_of(L"\\/") + 1) + L"Images\\";
    }

    bool exists(std::wstring const &path) {
        auto attributes = GetFileAttributesW(path.c_str());
        return attributes != INVALID_FILE_ATTRIBUTES && !(attributes & FILE_ATTRIBUTE_DIRECTORY);
    }

    winrt::Windows::Foundation::Uri address(std::wstring path) {
        for (auto &character : path) if (character == L'\\') character = L'/';
        return winrt::Windows::Foundation::Uri(L"file:///" + path);
    }

    /// Where attribute `name`'s value begins in an SVG's opening tag; npos for none.
    size_t attribute(std::string const &tag, std::string const &name) {
        for (auto at = tag.find(name); at != std::string::npos; at = tag.find(name, at + 1)) {
            if (at == 0 || !std::isspace(static_cast<unsigned char>(tag[at - 1]))) continue;
            auto next = tag.find_first_not_of(" \t\r\n", at + name.size());
            if (next == std::string::npos || tag[next] != '=') continue;
            next = tag.find_first_not_of(" \t\r\n", next + 1);
            if (next != std::string::npos && (tag[next] == '"' || tag[next] == '\'')) return next + 1;
        }
        return std::string::npos;
    }

    /// A length an SVG gives its picture, in DIPs; 0 for none, and for a share of a room it does not know.
    double length(std::string const &tag, std::string const &name) {
        auto at = attribute(tag, name);
        if (at == std::string::npos) return 0;
        char *end = nullptr;
        auto number = std::strtod(tag.c_str() + at, &end);
        std::string unit(end, std::strcspn(end, "\"' \t"));
        if (unit.empty() || unit == "px") return number;
        if (unit == "pt") return number * 96 / 72;
        if (unit == "pc") return number * 16;
        if (unit == "in") return number * 96;
        if (unit == "cm") return number * 96 / 2.54;
        if (unit == "mm") return number * 96 / 25.4;
        return 0;
    }

    /// Where an SVG's opening tag stands in its text, and how long it is; npos for none.
    std::pair<size_t, size_t> root(std::string const &text) {
        auto start = text.find("<svg");
        if (start == std::string::npos) return {start, 0};
        return {start, std::min(text.find('>', start), text.size()) - start};
    }

    /// The size an SVG declares, in DIPs: its width and height, the one missing taken from its viewBox's
    /// proportions, or its viewBox's; zero where it declares none.
    winrt::Windows::Foundation::Size declared(std::string const &text) {
        auto [start, span] = root(text);
        if (start == std::string::npos) return {};
        auto tag = text.substr(start, span);
        double width = length(tag, "width"), height = length(tag, "height");
        double box[4] = {};
        if (auto at = attribute(tag, "viewBox"); at != std::string::npos) {
            char const *cursor = tag.c_str() + at;
            for (auto &number : box) {
                char *end = nullptr;
                number = std::strtod(cursor, &end);
                cursor = end + std::strspn(end, ", \t\r\n");
            }
        }
        if (box[2] > 0 && box[3] > 0) {
            if (width <= 0 && height <= 0) width = box[2], height = box[3];
            else if (width <= 0) width = height * box[2] / box[3];
            else if (height <= 0) height = width * box[3] / box[2];
        }
        if (width <= 0 || height <= 0) return {};
        return {static_cast<float>(width), static_cast<float>(height)};
    }

    /// Makes the picture `text` draws fill whatever room it is drawn in: its proportions given up, and its own size
    /// too, which WinUI fits into the room in its proportions whatever the picture says of them.
    void letGoOfProportions(std::string &text) {
        std::pair<char const *, char const *> const values[] = {
            {"preserveAspectRatio", "none"}, {"width", "100%"}, {"height", "100%"}};
        for (auto const &[name, value] : values) {
            auto [start, span] = root(text);
            if (start == std::string::npos) return;
            auto tag = text.substr(start, span);
            if (auto at = attribute(tag, name); at != std::string::npos)
                text.replace(start + at, tag.find(tag[at - 1], at) - at, value);
            else
                text.insert(start + 4, std::string(" ") + name + "=\"" + value + "\"");
        }
    }

    std::string contents(std::wstring const &path) {
        std::string text;
        FILE *file = nullptr;
        if (_wfopen_s(&file, path.c_str(), L"rb") != 0 || !file) return text;
        char buffer[16384];
        for (size_t read; (read = std::fread(buffer, 1, sizeof buffer, file)) > 0;) text.append(buffer, read);
        std::fclose(file);
        return text;
    }

    /// A stream reading `size` bytes at `data` from a copy in memory.
    winrt::Windows::Storage::Streams::IRandomAccessStream memoryStream(void const *data, size_t size) {
        winrt::com_ptr<IStream> memory;
        memory.attach(SHCreateMemStream(static_cast<BYTE const *>(data), static_cast<UINT>(size)));
        if (!memory) winrt::throw_hresult(E_OUTOFMEMORY);
        winrt::Windows::Storage::Streams::IRandomAccessStream stream{nullptr};
        winrt::check_hresult(CreateRandomAccessStreamOverStream(
            memory.get(), BSOS_DEFAULT, winrt::guid_of<decltype(stream)>(), winrt::put_abi(stream)));
        return stream;
    }

    /// A bitmap of a picture's own `bytes`, read from memory; its size is known once it is read.
    imaging::BitmapImage bitmapOf(std::vector<uint8_t> const &bytes) {
        imaging::BitmapImage bitmap;
        bitmap.SetSourceAsync(memoryStream(bytes.data(), bytes.size()));
        return bitmap;
    }

    /// The bytes base64 `text` writes; what is no base64 digit - the padding - is passed over.
    std::vector<uint8_t> decoded(std::string_view text) {
        std::vector<uint8_t> bytes;
        bytes.reserve(text.size() / 4 * 3);
        uint32_t value = 0;
        int bits = 0;
        for (char each : text) {
            int digit = each >= 'A' && each <= 'Z' ? each - 'A'
                      : each >= 'a' && each <= 'z' ? each - 'a' + 26
                      : each >= '0' && each <= '9' ? each - '0' + 52
                      : each == '+' ? 62 : each == '/' ? 63 : -1;
            if (digit < 0) continue;
            value = ((value << 6) | static_cast<uint32_t>(digit)) & 0xFFFFFF;
            bits += 6;
            if (bits >= 8) {
                bits -= 8;
                bytes.push_back(static_cast<uint8_t>(value >> bits));
            }
        }
        return bytes;
    }

    /// An icon's glyph as the words a FontIcon shows.
    winrt::hstring glyphText(wchar_t glyph) {
        return winrt::hstring(std::wstring(1, glyph));
    }

    /// The name of an icon's glyph: `glyph:` and its code point in hex.
    std::wstring glyphName(winrt::hstring const &glyph) {
        if (glyph.empty()) return {};
        wchar_t hex[8] = {};
        swprintf_s(hex, L"%X", static_cast<unsigned>(glyph[0]));
        return std::wstring(L"glyph:") + hex;
    }

    /// The icon the relay draws a glyph in: the theme's font for symbols, as WinUI's own icons are.
    controls::FontIcon fontIcon(wchar_t glyph) {
        controls::FontIcon icon;
        icon.Glyph(glyphText(glyph));
        return icon;
    }

    /// What an SVG source is drawn from: its file, the pixels it is drawn at - none for WinUI's own - and whether
    /// its proportions are let go.
    struct Drawn {
        std::wstring file;
        uint32_t width = 0;
        uint32_t height = 0;
        bool stretched = false;

        bool operator<(Drawn const &other) const {
            return std::tie(file, width, height, stretched) < std::tie(other.file, other.width, other.height, other.stretched);
        }
    };

    /// The SVG sources standing, each read once and shared by every picture and window showing it.
    std::map<Drawn, winrt::weak_ref<imaging::SvgImageSource>> drawn;

    /// Where the SVG `file` stands with its proportions let go: a copy of its text with `preserveAspectRatio="none"`
    /// on its root among the system's temporary files, named by what it holds - every run showing the picture shares
    /// it, and none is left behind a run - written where it is missing, whole before it takes its name.
    std::wstring stretchedCopy(std::wstring const &file) {
        static std::map<std::wstring, std::wstring> copies;
        if (auto found = copies.find(file); found != copies.end()) return found->second;
        auto text = contents(pictures() + file);
        letGoOfProportions(text);
        wchar_t temporary[MAX_PATH] = {};
        GetTempPathW(MAX_PATH, temporary);
        std::wstring folder = std::wstring(temporary) + L"StateUI\\";
        CreateDirectoryW(folder.c_str(), nullptr);
        auto copy = folder + L"stretched-" + std::to_wstring(std::hash<std::string>{}(text)) + L".svg";
        if (GetFileAttributesW(copy.c_str()) == INVALID_FILE_ATTRIBUTES) {
            auto writing = copy + L"." + std::to_wstring(GetCurrentProcessId());
            FILE *written = nullptr;
            if (_wfopen_s(&written, writing.c_str(), L"wb") == 0 && written) {
                std::fwrite(text.data(), 1, text.size(), written);
                std::fclose(written);
                if (!MoveFileExW(writing.c_str(), copy.c_str(), MOVEFILE_REPLACE_EXISTING)) DeleteFileW(writing.c_str());
            }
        }
        copies[file] = copy;
        return copy;
    }

    /// The SVG `file` drawn at `width` x `height` pixels - WinUI's own size for none - its proportions let go where
    /// `stretched`: read by its file's address, as an SVG read from memory takes a surface the window's size, and
    /// one source for each, shared by every picture and window showing it.
    /// Design: docs/design/platforms/winui/controls.md#pictures
    imaging::SvgImageSource svg(std::wstring const &file, uint32_t width = 0, uint32_t height = 0, bool stretched = false) {
        Drawn key{file, width, height, stretched};
        if (auto found = drawn.find(key); found != drawn.end())
            if (auto source = found->second.get()) return source;
        for (auto each = drawn.begin(); each != drawn.end();) each = each->second.get() ? std::next(each) : drawn.erase(each);

        imaging::SvgImageSource source(address(stretched ? stretchedCopy(file) : pictures() + file));
        if (width > 0 && height > 0) {
            source.RasterizePixelWidth(width);
            source.RasterizePixelHeight(height);
        }
        drawn[key] = winrt::make_weak(source);
        return source;
    }

    bool isSvg(std::wstring const &file) {
        auto dot = file.find_last_of(L'.');
        return dot != std::wstring::npos && file.substr(dot) == L".svg";
    }

    /// What lines `names` - UTF-8, each ended by a line feed - ask to show: an icon's glyph (`glyph:` and its code
    /// point in hex), a picture's own bytes (`bytes:` and their base64), or the first of the files the pictures
    /// hold; and its name, by which a picture shown is told from another.
    struct Asked {
        wchar_t glyph = 0;
        std::vector<uint8_t> bytes;
        std::wstring file;
        std::wstring name;

        bool none() const { return !glyph && bytes.empty() && file.empty(); }
    };

    Asked asked(char const *names) {
        Asked asked;
        std::string_view first(names ? names : "");
        first = first.substr(0, first.find('\n'));
        if (first.rfind("glyph:", 0) == 0) {
            asked.glyph = static_cast<wchar_t>(std::strtoul(std::string(first.substr(6)).c_str(), nullptr, 16));
            asked.name = glyphName(glyphText(asked.glyph));
        } else if (first.rfind("bytes:", 0) == 0) {
            asked.bytes = decoded(first.substr(6));
            asked.name = L"bytes:" + std::to_wstring(asked.bytes.size()) + L":"
                + std::to_wstring(std::hash<std::string_view>{}(first));
        } else {
            asked.file = pictureFile(names);
            asked.name = asked.file;
        }
        return asked;
    }

    /// A source showing what is asked, which is no icon.
    xaml::Media::ImageSource sourceOf(Asked const &picture) {
        return picture.bytes.empty() ? pictureSource(picture.file) : bitmapOf(picture.bytes);
    }

    /// The image the Image element `handle` shows a bitmap or an SVG in; null while it shows an icon.
    controls::Image imageOf(StateUIObjectRef handle) {
        return borrow<controls::Border>(handle).Child().try_as<controls::Image>();
    }

    /// Hands `taking` what assistive technology met of `leaving`: the element shown in its place.
    void takeOver(xaml::UIElement const &leaving, xaml::UIElement const &taking) {
        using Properties = xaml::Automation::AutomationProperties;
        for (auto const &property : {Properties::NameProperty(), Properties::AutomationIdProperty(),
                                     Properties::HelpTextProperty(), Properties::HeadingLevelProperty(),
                                     Properties::AccessibilityViewProperty()}) {
            auto value = leaving.ReadLocalValue(property);
            if (value != xaml::DependencyProperty::UnsetValue()) taking.SetValue(property, value);
        }
    }
}

std::wstring stateui::pictureFile(char const *names) {
    std::string_view left(names ? names : "");
    while (!left.empty()) {
        auto end = left.find('\n');
        auto name = left.substr(0, end);
        std::wstring each(winrt::to_hstring(name).c_str());
        if (!each.empty() && exists(pictures() + each)) return each;
        if (end == std::string_view::npos) break;
        left.remove_prefix(end + 1);
    }
    return {};
}

xaml::Media::ImageSource stateui::pictureSource(std::wstring const &file) {
    if (isSvg(file)) return svg(file);
    return imaging::BitmapImage(address(pictures() + file));
}

std::wstring stateui::pictureName(char const *names) {
    return asked(names).name;
}

controls::IconElement stateui::pictureIcon(char const *names) {
    auto picture = asked(names);
    if (picture.glyph) return fontIcon(picture.glyph);
    if (picture.none()) return nullptr;
    controls::ImageIcon icon;
    icon.Source(sourceOf(picture));
    icon.Tag(winrt::box_value(winrt::hstring(picture.name)));
    return icon;
}

xaml::FrameworkElement stateui::pictureImage(char const *names) {
    auto picture = asked(names);
    if (picture.glyph) return fontIcon(picture.glyph);
    if (picture.none()) return nullptr;
    controls::Image image;
    if (isSvg(picture.file)) {
        if (auto own = declared(contents(pictures() + picture.file)); own.Width > 0) {
            image.Width(own.Width);
            image.Height(own.Height);
        }
    }
    image.Source(sourceOf(picture));
    image.Tag(winrt::box_value(winrt::hstring(picture.name)));
    return image;
}

controls::IconSource stateui::pictureIconSource(char const *names) {
    auto picture = asked(names);
    if (picture.glyph) {
        controls::FontIconSource icon;
        icon.Glyph(glyphText(picture.glyph));
        return icon;
    }
    if (picture.none()) return nullptr;
    controls::ImageIconSource icon;
    icon.ImageSource(sourceOf(picture));
    return icon;
}

std::wstring stateui::shownName(xaml::UIElement const &shown) {
    if (auto icon = shown.try_as<controls::FontIcon>()) return glyphName(icon.Glyph());
    if (auto element = shown.try_as<xaml::FrameworkElement>())
        return winrt::unbox_value_or<winrt::hstring>(element.Tag(), L"").c_str();
    return {};
}

std::wstring stateui::sourceFile(xaml::Media::ImageSource const &source) {
    if (!source) return {};
    if (auto shown = source.try_as<imaging::SvgImageSource>()) {
        for (auto const &[key, held] : drawn)
            if (held.get() == shown) return key.file;
        return {};
    }
    auto bitmap = source.try_as<imaging::BitmapImage>();
    auto at = bitmap ? bitmap.UriSource() : nullptr;
    if (!at) return {};
    std::wstring path(at.Path());
    return path.substr(path.find_last_of(L'/') + 1);
}

std::wstring stateui::sourceFile(controls::IconSource const &icon) {
    if (auto glyph = icon ? icon.try_as<controls::FontIconSource>() : nullptr) return glyphName(glyph.Glyph());
    auto pictured = icon ? icon.try_as<controls::ImageIconSource>() : nullptr;
    return pictured ? sourceFile(pictured.ImageSource()) : std::wstring();
}

std::wstring stateui::iconFile(controls::IconElement const &icon) {
    if (auto glyph = icon ? icon.try_as<controls::FontIcon>() : nullptr) return glyphName(glyph.Glyph());
    auto pictured = icon ? icon.try_as<controls::ImageIcon>() : nullptr;
    if (!pictured) return {};
    auto file = sourceFile(pictured.Source());
    return file.empty() ? shownName(pictured) : file;
}

extern "C" void stateui_winui_set_pictures(char const *utf8) {
    try {
        folder = winrt::to_hstring(std::string_view(utf8 ? utf8 : "")).c_str();
        if (!folder.empty() && folder.back() != L'\\' && folder.back() != L'/') folder += L'\\';
    } catch (...) {
        report("naming the pictures' folder");
    }
}

extern "C" StateUIObjectRef stateui_winui_image_make(void) {
    try {
        // The picture stands in a border, which holds an image, or a FontIcon in a box for an icon.
        controls::Border frame;
        frame.Child(controls::Image());
        return detach(frame);
    } catch (...) {
        report("making an image");
        return nullptr;
    }
}

extern "C" bool stateui_winui_image_set(
    StateUIObjectRef handle, char const *const *names, int32_t count, int32_t aspect, double *size
) {
    size[0] = size[1] = 0;
    try {
        auto frame = borrow<controls::Border>(handle);
        // StateUI's ContentMode: fit, fill, stretch, center - at the picture's own size, in the middle of the room.
        auto centered = aspect == 3;
        auto stretch = aspect == 1 ? xaml::Media::Stretch::UniformToFill
                     : aspect == 2 ? xaml::Media::Stretch::Fill
                     : centered ? xaml::Media::Stretch::None : xaml::Media::Stretch::Uniform;
        std::string listed;
        for (int32_t index = 0; index < count; ++index) listed += std::string(names[index] ? names[index] : "") + "\n";
        auto picture = asked(listed.c_str());

        // An icon is a FontIcon at its own size, fitted to the room by a box; what assistive technology met of the
        // picture before is the icon's.
        // Design: docs/design/platforms/winui/controls.md#icons
        auto shown = frame.Child().as<xaml::UIElement>();
        if (picture.glyph) {
            auto icon = fontIcon(picture.glyph);
            controls::Viewbox box;
            box.Stretch(stretch);
            box.Child(icon);
            if (!shown.try_as<controls::Viewbox>()) takeOver(shown, icon);
            frame.Child(box);
            size[0] = size[1] = icon.FontSize();
            return true;
        }
        auto image = shown.try_as<controls::Image>();
        if (!image) {
            image = controls::Image();
            if (auto box = shown.try_as<controls::Viewbox>()) takeOver(box.Child(), image);
            frame.Child(image);
        }
        image.Stretch(stretch);
        image.HorizontalAlignment(centered ? xaml::HorizontalAlignment::Center : xaml::HorizontalAlignment::Stretch);
        image.VerticalAlignment(centered ? xaml::VerticalAlignment::Center : xaml::VerticalAlignment::Stretch);
        image.ClearValue(xaml::FrameworkElement::WidthProperty());
        image.ClearValue(xaml::FrameworkElement::HeightProperty());

        // The first of the files the name stands for that the pictures hold, or the picture's own bytes.
        auto file = picture.file;
        auto named = count > 0 && names[0] && *names[0];
        image.Tag(winrt::box_value(winrt::hstring(picture.name)));
        if (picture.none()) {
            image.Source(nullptr);
            return !named;
        }
        if (!picture.bytes.empty() || !isSvg(file)) {
            // A bitmap's size is known once it is read; the layout holding it measures it again then.
            auto bitmap = picture.bytes.empty() ? imaging::BitmapImage(address(pictures() + file)) : bitmapOf(picture.bytes);
            bitmap.ImageOpened(guarded("handling ImageOpened",
                [held = winrt::make_weak(frame)](auto const &, xaml::RoutedEventArgs const &) {
                auto frame = held.get();
                if (!frame) return;
                if (auto layout = xaml::Media::VisualTreeHelper::GetParent(frame).try_as<xaml::UIElement>())
                    layout.InvalidateMeasure();
            }));
            image.Source(bitmap);
            return true;
        }
        auto path = pictures() + file;
        auto text = contents(path);
        auto own = declared(text);
        size[0] = own.Width;
        size[1] = own.Height;
        // WinUI takes an SVG's pixels for DIPs: centered, it is drawn at its own size by the image's.
        if (centered && own.Width > 0) {
            image.Stretch(xaml::Media::Stretch::Uniform);
            image.Width(own.Width);
            image.Height(own.Height);
        }
        // Drawn at WinUI's own size until it is drawn at the size it shows at; a stretched one, its proportions let
        // go, at the room's.
        // Design: docs/design/platforms/winui/controls.md#pictures
        image.Source(svg(file, 0, 0, aspect == 2));
        return true;
    } catch (...) {
        report("showing a picture");
        return false;
    }
}

extern "C" void stateui_winui_image_size(StateUIObjectRef handle, double *size) {
    size[0] = size[1] = 0;
    try {
        auto image = imageOf(handle);
        auto bitmap = image ? image.Source().try_as<imaging::BitmapImage>() : nullptr;
        if (!bitmap) return;
        size[0] = bitmap.PixelWidth();
        size[1] = bitmap.PixelHeight();
    } catch (...) {
        report("reading a picture's size");
    }
}

extern "C" void stateui_winui_svgs_read(StateUIObjectRef handle, int32_t *counts) {
    counts[0] = counts[1] = 0;
    try {
        // Every picture and icon under the element, its SVG source read by its file's address or not.
        std::function<void(xaml::DependencyObject const &)> walk = [&](xaml::DependencyObject const &node) {
            imaging::SvgImageSource source{nullptr};
            if (auto image = node.try_as<controls::Image>()) source = image.Source().try_as<imaging::SvgImageSource>();
            if (auto icon = node.try_as<controls::ImageIcon>()) source = icon.Source().try_as<imaging::SvgImageSource>();
            if (source) ++counts[source.UriSource() ? 0 : 1];
            for (int32_t index = 0, count = xaml::Media::VisualTreeHelper::GetChildrenCount(node); index < count; ++index)
                walk(xaml::Media::VisualTreeHelper::GetChild(node, index));
        };
        walk(as<xaml::DependencyObject>(handle));
    } catch (...) {
        report("counting the SVGs an element shows");
    }
}

extern "C" void stateui_winui_image_draw(StateUIObjectRef handle, double width, double height) {
    try {
        // The source of its file drawn at that size, which every picture showing it at that size shares.
        auto image = imageOf(handle);
        if (!image) return;
        std::wstring file(winrt::unbox_value_or<winrt::hstring>(image.Tag(), L"").c_str());
        if (!isSvg(file)) return;
        auto scale = image.XamlRoot() ? image.XamlRoot().RasterizationScale() : 1.0;
        image.Source(svg(file, static_cast<uint32_t>(std::ceil(width * scale)),
                         static_cast<uint32_t>(std::ceil(height * scale)),
                         image.Stretch() == xaml::Media::Stretch::Fill));
    } catch (...) {
        report("drawing a picture");
    }
}
