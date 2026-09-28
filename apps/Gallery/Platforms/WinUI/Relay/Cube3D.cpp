// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A cube drawn by Direct3D 11.1 into WinUI's SwapChainPanel - an element that knows nothing of StateUI. Its device
// asks for feature level 11_1 alone; its swap chain is the panel's, sized in pixels for the panel's scale; it turns
// on WinUI's frames only while it spins and stands on screen, so nothing turns behind a page the user has left, and
// a value changed while it stands still draws the one frame it needs.

#include "Relay.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <memory>
#include <unordered_map>
#include <vector>

#include <d3d11_1.h>
#include <d3dcompiler.h>
#include <dxgi1_3.h>
#include <microsoft.ui.xaml.media.dxinterop.h>

using namespace gallery;
using winrt::com_ptr;
using winrt::check_hresult;

namespace {
    /// The colours a cube is painted: teal, amber, violet.
    constexpr float paints[3][3] = {{0.161f, 0.722f, 0.678f}, {0.961f, 0.710f, 0.275f}, {0.580f, 0.443f, 0.929f}};

    /// The shaders: each corner carries its face's brightness in w, and the colour is the frame's.
    constexpr char shaders[] = R"(
        cbuffer Frame : register(b0) { float4x4 transform; float4 color; };
        struct Corner { float4 at : POSITION; };
        struct Painted { float4 position : SV_POSITION; float4 color : COLOR; };
        Painted vertex(Corner corner) {
            Painted painted;
            painted.position = mul(transform, float4(corner.at.xyz, 1));
            painted.color = float4(color.rgb * corner.at.w, color.a);
            return painted;
        }
        float4 pixel(Painted painted) : SV_TARGET { return painted.color; }
    )";

    struct Frame {
        float transform[16];
        float color[4];
    };

    /// One cube: what it shows, and the device, the swap chain and the targets it draws with.
    struct Cube {
        winrt::weak_ref<controls::SwapChainPanel> panel;
        double size = 0.6;
        int32_t color = 0;
        bool spinning = true;
        bool shown = false;
        double angle = 0;
        double lastFrame = -1;
        winrt::event_token rendering{};

        D3D_FEATURE_LEVEL level{};
        com_ptr<ID3D11Device1> device;
        com_ptr<ID3D11DeviceContext1> context;
        com_ptr<IDXGISwapChain1> chain;
        com_ptr<ID3D11RenderTargetView> target;
        com_ptr<ID3D11DepthStencilView> depth;
        com_ptr<ID3D11VertexShader> vertexShader;
        com_ptr<ID3D11PixelShader> pixelShader;
        com_ptr<ID3D11InputLayout> layout;
        com_ptr<ID3D11Buffer> corners;
        com_ptr<ID3D11Buffer> frame;
        com_ptr<ID3D11RasterizerState> bothSides;
        com_ptr<ID3D11DepthStencilState> nearest;
        UINT width = 0;
        UINT height = 0;
    };

    /// Every cube, by its panel's identity.
    std::unordered_map<void *, std::shared_ptr<Cube>> cubes;

    void *identity(controls::SwapChainPanel const &panel) {
        return winrt::get_abi(panel.as<winrt::Windows::Foundation::IUnknown>());
    }

    std::shared_ptr<Cube> cube(GalleryObjectRef handle) {
        auto found = cubes.find(identity(as<controls::SwapChainPanel>(handle)));
        return found == cubes.end() ? nullptr : found->second;
    }

    /// Six faces of two triangles each, every corner its position and its face's brightness in w.
    std::vector<float> faces() {
        float const corners[6][4][3] = {
            {{1, -1, -1}, {1, 1, -1}, {1, 1, 1}, {1, -1, 1}},       {{-1, -1, -1}, {-1, 1, -1}, {-1, 1, 1}, {-1, -1, 1}},
            {{-1, 1, -1}, {1, 1, -1}, {1, 1, 1}, {-1, 1, 1}},       {{-1, -1, -1}, {1, -1, -1}, {1, -1, 1}, {-1, -1, 1}},
            {{-1, -1, 1}, {1, -1, 1}, {1, 1, 1}, {-1, 1, 1}},       {{-1, -1, -1}, {1, -1, -1}, {1, 1, -1}, {-1, 1, -1}},
        };
        float const shades[6] = {1.00f, 0.55f, 0.88f, 0.42f, 0.97f, 0.50f};
        std::vector<float> made;
        for (int face = 0; face < 6; ++face) {
            for (int corner : {0, 1, 2, 0, 2, 3}) {
                made.insert(made.end(), {corners[face][corner][0], corners[face][corner][1], corners[face][corner][2],
                                         shades[face]});
            }
        }
        return made;
    }

    /// Column by column: the left matrix after the right.
    void multiply(float const *left, float const *right, float *product) {
        float result[16] = {};
        for (int column = 0; column < 4; ++column) {
            for (int row = 0; row < 4; ++row) {
                for (int step = 0; step < 4; ++step) result[column * 4 + row] += left[step * 4 + row] * right[column * 4 + step];
            }
        }
        std::copy(result, result + 16, product);
    }

    /// Perspective with Direct3D's depth from 0 to 1, turned about x and y, scaled, and set back along z.
    void transform(double aspect, double turn, double scale, float *matrix) {
        // `near` and `far` are Windows' own macros.
        double const focal = 1 / std::tan(50 * 3.14159265358979 / 360), closest = 0.1, farthest = 100;
        float perspective[16] = {};
        perspective[0] = static_cast<float>(focal / aspect);
        perspective[5] = static_cast<float>(focal);
        perspective[10] = static_cast<float>(farthest / (closest - farthest));
        perspective[11] = -1;
        perspective[14] = static_cast<float>(closest * farthest / (closest - farthest));
        float back[16] = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, -4, 1};
        auto x = turn * 0.35, y = turn * 0.60;
        float aboutX[16] = {1, 0, 0, 0, 0, float(std::cos(x)), float(std::sin(x)), 0,
                            0, float(-std::sin(x)), float(std::cos(x)), 0, 0, 0, 0, 1};
        float aboutY[16] = {float(std::cos(y)), 0, float(-std::sin(y)), 0, 0, 1, 0, 0,
                            float(std::sin(y)), 0, float(std::cos(y)), 0, 0, 0, 0, 1};
        float scaled[16] = {float(scale), 0, 0, 0, 0, float(scale), 0, 0, 0, 0, float(scale), 0, 0, 0, 0, 1};
        float turned[16], placed[16];
        multiply(aboutY, scaled, turned);
        multiply(aboutX, turned, turned);
        multiply(back, turned, placed);
        multiply(perspective, placed, matrix);
    }

    com_ptr<ID3DBlob> compile(char const *entry, char const *profile) {
        com_ptr<ID3DBlob> code, errors;
        auto result = D3DCompile(shaders, sizeof shaders - 1, "Cube3D", nullptr, nullptr, entry, profile, 0, 0,
                                 code.put(), errors.put());
        if (FAILED(result)) {
            throw winrt::hresult_error(result, winrt::to_hstring(errors ? static_cast<char const *>(
                errors->GetBufferPointer()) : "the cube's shaders did not compile"));
        }
        return code;
    }

    /// The device at feature level 11_1, the shaders, the corners and the states, made once.
    void makeDevice(Cube &cube) {
        D3D_FEATURE_LEVEL const levels[] = {D3D_FEATURE_LEVEL_11_1};
        com_ptr<ID3D11Device> device;
        com_ptr<ID3D11DeviceContext> context;
        check_hresult(D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, D3D11_CREATE_DEVICE_BGRA_SUPPORT,
                                        levels, 1, D3D11_SDK_VERSION, device.put(), &cube.level, context.put()));
        cube.device = device.as<ID3D11Device1>();
        cube.context = context.as<ID3D11DeviceContext1>();

        auto vertex = compile("vertex", "vs_5_0");
        auto pixel = compile("pixel", "ps_5_0");
        check_hresult(cube.device->CreateVertexShader(vertex->GetBufferPointer(), vertex->GetBufferSize(), nullptr,
                                                      cube.vertexShader.put()));
        check_hresult(cube.device->CreatePixelShader(pixel->GetBufferPointer(), pixel->GetBufferSize(), nullptr,
                                                     cube.pixelShader.put()));
        D3D11_INPUT_ELEMENT_DESC const corner{"POSITION", 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 0,
                                              D3D11_INPUT_PER_VERTEX_DATA, 0};
        check_hresult(cube.device->CreateInputLayout(&corner, 1, vertex->GetBufferPointer(), vertex->GetBufferSize(),
                                                     cube.layout.put()));

        auto made = faces();
        D3D11_BUFFER_DESC corners{static_cast<UINT>(made.size() * sizeof(float)), D3D11_USAGE_IMMUTABLE,
                                  D3D11_BIND_VERTEX_BUFFER, 0, 0, 0};
        D3D11_SUBRESOURCE_DATA data{made.data(), 0, 0};
        check_hresult(cube.device->CreateBuffer(&corners, &data, cube.corners.put()));
        D3D11_BUFFER_DESC frame{sizeof(Frame), D3D11_USAGE_DEFAULT, D3D11_BIND_CONSTANT_BUFFER, 0, 0, 0};
        check_hresult(cube.device->CreateBuffer(&frame, nullptr, cube.frame.put()));

        D3D11_RASTERIZER_DESC sides{};
        sides.FillMode = D3D11_FILL_SOLID;
        sides.CullMode = D3D11_CULL_NONE;
        sides.DepthClipEnable = TRUE;
        check_hresult(cube.device->CreateRasterizerState(&sides, cube.bothSides.put()));
        D3D11_DEPTH_STENCIL_DESC nearest{};
        nearest.DepthEnable = TRUE;
        nearest.DepthWriteMask = D3D11_DEPTH_WRITE_MASK_ALL;
        nearest.DepthFunc = D3D11_COMPARISON_LESS;
        check_hresult(cube.device->CreateDepthStencilState(&nearest, cube.nearest.put()));
    }

    /// The swap chain and its targets for the panel's size and scale: made the first time, sized again after.
    void standChain(Cube &cube, controls::SwapChainPanel const &panel) {
        auto scaleX = panel.CompositionScaleX(), scaleY = panel.CompositionScaleY();
        auto width = static_cast<UINT>(std::max(1.0, std::round(panel.ActualWidth() * scaleX)));
        auto height = static_cast<UINT>(std::max(1.0, std::round(panel.ActualHeight() * scaleY)));
        if (cube.chain && width == cube.width && height == cube.height) return;

        if (!cube.device) makeDevice(cube);
        cube.target = nullptr;
        cube.depth = nullptr;
        cube.context->OMSetRenderTargets(0, nullptr, nullptr);
        if (cube.chain) {
            check_hresult(cube.chain->ResizeBuffers(2, width, height, DXGI_FORMAT_B8G8R8A8_UNORM, 0));
        } else {
            com_ptr<IDXGIFactory2> factory;
            com_ptr<IDXGIAdapter> adapter;
            check_hresult(cube.device.as<IDXGIDevice>()->GetAdapter(adapter.put()));
            check_hresult(adapter->GetParent(IID_PPV_ARGS(factory.put())));
            DXGI_SWAP_CHAIN_DESC1 chain{};
            chain.Width = width;
            chain.Height = height;
            chain.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
            chain.SampleDesc.Count = 1;
            chain.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
            chain.BufferCount = 2;
            chain.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
            chain.AlphaMode = DXGI_ALPHA_MODE_PREMULTIPLIED;
            chain.Scaling = DXGI_SCALING_STRETCH;
            check_hresult(factory->CreateSwapChainForComposition(cube.device.get(), &chain, nullptr, cube.chain.put()));
            check_hresult(panel.as<ISwapChainPanelNative>()->SetSwapChain(cube.chain.get()));
        }
        // Drawn in pixels, shown in the panel's DIPs.
        DXGI_MATRIX_3X2_F inverse{};
        inverse._11 = static_cast<float>(1 / scaleX);
        inverse._22 = static_cast<float>(1 / scaleY);
        check_hresult(cube.chain.as<IDXGISwapChain2>()->SetMatrixTransform(&inverse));
        cube.width = width;
        cube.height = height;

        com_ptr<ID3D11Texture2D> buffer;
        check_hresult(cube.chain->GetBuffer(0, IID_PPV_ARGS(buffer.put())));
        check_hresult(cube.device->CreateRenderTargetView(buffer.get(), nullptr, cube.target.put()));
        D3D11_TEXTURE2D_DESC depth{width, height, 1, 1, DXGI_FORMAT_D24_UNORM_S8_UINT, {1, 0}, D3D11_USAGE_DEFAULT,
                                   D3D11_BIND_DEPTH_STENCIL, 0, 0};
        com_ptr<ID3D11Texture2D> depthBuffer;
        check_hresult(cube.device->CreateTexture2D(&depth, nullptr, depthBuffer.put()));
        check_hresult(cube.device->CreateDepthStencilView(depthBuffer.get(), nullptr, cube.depth.put()));
    }

    /// Clears to the housing's colour and draws the cube: turned, scaled and seen in perspective.
    void draw(Cube &cube) {
        auto panel = cube.panel.get();
        if (!panel || panel.ActualWidth() < 1 || panel.ActualHeight() < 1) return;
        standChain(cube, panel);

        float const housing[4] = {0.102f, 0.090f, 0.145f, 1};
        auto target = cube.target.get();
        cube.context->OMSetRenderTargets(1, &target, cube.depth.get());
        cube.context->ClearRenderTargetView(target, housing);
        cube.context->ClearDepthStencilView(cube.depth.get(), D3D11_CLEAR_DEPTH, 1, 0);
        D3D11_VIEWPORT viewport{0, 0, static_cast<float>(cube.width), static_cast<float>(cube.height), 0, 1};
        cube.context->RSSetViewports(1, &viewport);

        Frame frame{};
        transform(double(cube.width) / cube.height, cube.angle, std::clamp(cube.size, 0.0, 1.0), frame.transform);
        auto const &paint = paints[std::clamp(cube.color, 0, 2)];
        std::copy(paint, paint + 3, frame.color);
        frame.color[3] = 1;
        cube.context->UpdateSubresource(cube.frame.get(), 0, nullptr, &frame, 0, 0);

        UINT const stride = 4 * sizeof(float), offset = 0;
        auto corners = cube.corners.get();
        auto constants = cube.frame.get();
        cube.context->IASetInputLayout(cube.layout.get());
        cube.context->IASetVertexBuffers(0, 1, &corners, &stride, &offset);
        cube.context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        cube.context->VSSetShader(cube.vertexShader.get(), nullptr, 0);
        cube.context->VSSetConstantBuffers(0, 1, &constants);
        cube.context->PSSetShader(cube.pixelShader.get(), nullptr, 0);
        cube.context->RSSetState(cube.bothSides.get());
        cube.context->OMSetDepthStencilState(cube.nearest.get(), 0);
        cube.context->Draw(36, 0);
        check_hresult(cube.chain->Present(1, 0));
    }

    /// Follows WinUI's frames while the cube spins and stands on screen, and lets go of them otherwise.
    void followFrames(std::shared_ptr<Cube> const &cube) {
        auto follows = static_cast<bool>(cube->rendering);
        if (cube->spinning && cube->shown && !follows) {
            cube->lastFrame = -1;
            std::weak_ptr<Cube> weak = cube;
            cube->rendering = xaml::Media::CompositionTarget::Rendering(
                [weak](auto const &, winrt::Windows::Foundation::IInspectable const &args) {
                    auto cube = weak.lock();
                    if (!cube) return;
                    try {
                        auto now = std::chrono::duration<double>(
                            args.as<xaml::Media::RenderingEventArgs>().RenderingTime()).count();
                        if (cube->lastFrame >= 0) cube->angle += now - cube->lastFrame;
                        cube->lastFrame = now;
                        draw(*cube);
                    } catch (...) {
                        report("drawing the cube");
                    }
                });
        } else if (!(cube->spinning && cube->shown) && follows) {
            xaml::Media::CompositionTarget::Rendering(cube->rendering);
            cube->rendering = {};
        }
    }
}

extern "C" GalleryObjectRef gallery_cube_make(void) {
    try {
        controls::SwapChainPanel panel;
        panel.MinWidth(240);
        panel.MinHeight(240);
        auto cube = std::make_shared<Cube>();
        cube->panel = winrt::make_weak(panel);
        std::weak_ptr<Cube> weak = cube;
        panel.Loaded([weak](auto const &, auto const &) {
            if (auto cube = weak.lock()) {
                cube->shown = true;
                followFrames(cube);
                try { draw(*cube); } catch (...) { report("drawing the cube"); }
            }
        });
        panel.Unloaded([weak](auto const &, auto const &) {
            if (auto cube = weak.lock()) {
                cube->shown = false;
                followFrames(cube);
            }
        });
        auto redraw = [weak](auto const &, auto const &) {
            if (auto cube = weak.lock()) {
                try { draw(*cube); } catch (...) { report("drawing the cube"); }
            }
        };
        panel.SizeChanged(redraw);
        panel.CompositionScaleChanged(redraw);
        cubes[identity(panel)] = cube;
        return detach(panel);
    } catch (...) {
        report("making a cube");
        return nullptr;
    }
}

extern "C" void gallery_cube_set(GalleryObjectRef handle, double size, int32_t color, bool spinning) {
    try {
        auto found = cube(handle);
        if (!found) return;
        found->size = size;
        found->color = color;
        found->spinning = spinning;
        followFrames(found);
        if (found->shown) draw(*found);
    } catch (...) {
        report("setting the cube");
    }
}

extern "C" void gallery_cube_close(GalleryObjectRef handle) {
    try {
        auto key = identity(as<controls::SwapChainPanel>(handle));
        auto found = cubes.find(key);
        if (found == cubes.end()) return;
        found->second->spinning = false;
        followFrames(found->second);
        cubes.erase(found);
    } catch (...) {
        report("closing the cube");
    }
}

extern "C" int32_t gallery_cube_feature_level(GalleryObjectRef handle) {
    try {
        auto found = cube(handle);
        return found && found->device ? static_cast<int32_t>(found->level) : 0;
    } catch (...) {
        report("reading the cube's feature level");
        return 0;
    }
}
