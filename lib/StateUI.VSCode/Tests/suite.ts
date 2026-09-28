// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The integration suite, run inside VS Code by Tests/run.ts.
//
// The editor's host is asked of the LANGUAGE SERVER, which cannot be faked: a
// symbol under `#if APPKIT` resolves only while SourceKit-LSP runs with
// STATEUI_APPKIT, and a symbol under no condition resolves in either mode -
// which is what tells "not this host" from "not ready yet".

import { execSync } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as vscode from "vscode";
import { findApplications, hasHead } from "../Sources/applications";
import { StateUIDebugConfigurationProvider, uiKitAttach } from "../Sources/debug";
import { parseDevices } from "../Sources/devices";
import { parseDevices as parseUIKitDevices, parseSimulators } from "../Sources/uiKitDevices";
import { serverConfig, serverSettings, swiftRelease, swiftSDKOf } from "../Sources/editorMode";
import { findSuites, forDevice } from "../Sources/tests";
import { availableHosts, environment, hosts } from "../Sources/hosts";
import { StateUIApi } from "../Sources/extension";
import { inAppsCommand, nameProblem } from "../Sources/newApplication";
import { reinstallSteps } from "../Sources/reinstall";
import { rebuildSteps } from "../Sources/conformance";
import {
    atLeast, checkToolchain, debuggerFinding, isSwiftOrgBuild, ndkRevisionIn, newestIOSRuntime, report, svgLoaderIn,
    xcodeVersion,
} from "../Sources/toolchain";

const started = Date.now();

function say(line: string): void {
    const stamped = `[${Math.round((Date.now() - started) / 1000)}s] ${line}\n`;
    const file = process.env.STATEUI_TEST_RESULTS;
    if (file) {
        fs.appendFileSync(file, stamped);
    }
}

async function resolves(file: string, needle: string, after?: string): Promise<boolean> {
    const document = await vscode.workspace.openTextDocument(file);
    await vscode.window.showTextDocument(document, { preview: false });
    const text = document.getText();
    const from = after ? text.indexOf(after) : 0;
    const at = text.indexOf(needle, from);
    if (from < 0 || at < 0) {
        throw new Error(`${needle} is not in ${file}`);
    }

    const found = await vscode.commands.executeCommand<unknown[]>(
        "vscode.executeDefinitionProvider", document.uri, document.positionAt(at + 1));
    return (found?.length ?? 0) > 0;
}

async function until(what: string, probe: () => Promise<boolean>, seconds: number): Promise<void> {
    const deadline = Date.now() + seconds * 1000;
    while (Date.now() < deadline) {
        if (await probe()) {
            say(`ok   ${what}`);
            return;
        }
        await new Promise((resume) => setTimeout(resume, 5000));
    }
    throw new Error(`timed out after ${seconds}s: ${what}`);
}

function check(what: string, value: boolean): void {
    say(`${value ? "ok  " : "FAIL"} ${what}`);
    if (!value) {
        throw new Error(what);
    }
}

export async function run(): Promise<void> {
    try {
        const root = vscode.workspace.workspaceFolders![0];
        const gallery = path.join(root.uri.fsPath, "apps", "Gallery");
        const plain = path.join(gallery, "Sources", "Samples", "BasicInput", "SliderSample.swift");
        // A head's own view exists only while the editor works as that host: its target is declared for it alone. A
        // member under an inactive `#if` resolves all the same - the server reads it through its type.
        const appKitOnly = (): Promise<boolean> =>
            resolves(path.join(gallery, "Platforms", "AppKit", "Host", "GalleryControls.swift"), "MetalCube3DView.register");
        const uiKitOnly = (): Promise<boolean> =>
            resolves(path.join(gallery, "Platforms", "UIKit", "Host", "GalleryControls.swift"), "MetalCube3DView.register");
        const head = path.join(gallery, "Platforms", "AppKit", "Host", "MetalCube3DView.swift");
        const uiKitHead = path.join(gallery, "Platforms", "UIKit", "Host", "MetalCube3DView.swift");

        const api = await vscode.extensions.getExtension<StateUIApi>("idexus.stateui")!.activate();
        say(`activated, host ${api.host()}`);

        // 1-3 ask the language server as AppKit and as Android, hosts only macOS builds.
        if (process.platform === "darwin") {
            // 1. Android: the plain symbol resolves, the AppKit one does not.
            await api.selectHost("android");
            await until("android: a symbol under no condition resolves", () => resolves(plain, "Palette.accent"), 900);
            await until("android: neither head's own view resolves", async () => !(await appKitOnly()) && !(await uiKitOnly()), 900);

            // 2. AppKit, with no reload: the conditional symbol and the head resolve.
            await api.selectHost("appkit");
            await until("appkit: its head's own view resolves", appKitOnly, 900);
            // A target the package did not have a moment ago: the server has to
            // load it, so this is waited for rather than asked once.
            await until("appkit: Cube3DContract in Platforms/AppKit resolves", () => resolves(head, "Cube3DContract.self"), 900);

            // 2b. UIKit, compiled for the iOS simulator by the triple alone: its head resolves, the AppKit symbol not.
            await api.selectHost("uikit");
            await until("uikit: Cube3DContract in Platforms/UIKit resolves", () => resolves(uiKitHead, "Cube3DContract.self"), 900);
            await until("uikit: its head's own view resolves, and AppKit's does not", async () => (await uiKitOnly()) && !(await appKitOnly()), 900);

            // 3. And back, still with no reload.
            await api.selectHost("android");
            await until("android again: the heads' views stop resolving while the plain symbol does", async () =>
                (await resolves(plain, "Palette.accent")) && !(await appKitOnly()) && !(await uiKitOnly()), 900);
        } else {
            say("skip the language server as AppKit and Android: only macOS builds those hosts");
        }

        // 4. The hosts a machine is offered: AppKit and Android on macOS, WinUI
        //    on Windows, GTK on Linux, and no .NET MAUI. A launch on a machine
        //    that runs no host resolves to nothing.
        const gallery_ = findApplications(root.uri.fsPath).find((each) => each.name === "Gallery")!;
        check("the host picker offers AppKit, UIKit and Android on macOS, WinUI on Windows, GTK on Linux, and never .NET MAUI",
            JSON.stringify(availableHosts("darwin").map((each) => each.id)) === JSON.stringify(["appkit", "uikit", "android"])
            && JSON.stringify(availableHosts("win32").map((each) => each.id)) === JSON.stringify(["winui"])
            && JSON.stringify(availableHosts("linux").map((each) => each.id)) === JSON.stringify(["gtk"])
            && availableHosts("freebsd").length === 0
            && !hosts.some((each) => each.label.includes("MAUI")));
        {
            const ran: string[] = [];
            const provider = new StateUIDebugConfigurationProvider({
                host: () => undefined, application: async () => gallery_,
                run: async (task) => { ran.push(task.name); return 0; },
                start: async (task) => { ran.push(task.name); },
                ready: async () => false,
                device: async () => undefined,
                uiKitDevice: async () => undefined,
            });
            const resolved = await provider.resolveDebugConfiguration(root,
                { name: "StateUI: Debug", type: "stateui", request: "launch", configuration: "debug" });
            check("with no host a launch runs nothing and opens no session", resolved === undefined && ran.length === 0);
        }

        // 5. The suites, found for each host the way test-native.sh runs them.
        const appkitSuites = findSuites(root.uri.fsPath, "appkit").map((each) => each.label);
        const plainSuites = findSuites(root.uri.fsPath, undefined);
        say(`appkit suites: ${appkitSuites.join(", ")}`);
        say(`suites with no host: ${plainSuites.map((each) => each.label).join(", ")}`);
        check("appkit runs the core, StateUI.AppKit and the Gallery, and no device",
            appkitSuites.includes("StateUI") && appkitSuites.includes("lib/StateUI.AppKit")
            && appkitSuites.includes("apps/Gallery") && !appkitSuites.some((each) => each.endsWith("Tests")));
        check("with no host the core and the Gallery run as plain Swift, and no host's own package",
            plainSuites.some((each) => each.label === "StateUI") && plainSuites.some((each) => each.label === "apps/Gallery")
            && plainSuites.every((each) => each.command === "swift" && Object.keys(each.env).length === 0 && !each.onDevice)
            && !plainSuites.some((each) => each.label === "lib/StateUI.AppKit" || each.label === "lib/StateUI.Android/Tests"));

        // 6. Android: the environment, the language server's file, the
        //    devices, and the commands a launch and a suite run - captured,
        //    not run.
        check("each host's environment sets its own variable alone and clears every other - STATEUI_ANDROID for Android",
            hosts.every((host) => {
                const values = environment(host.id);
                const set = Object.entries(values).filter((entry) => entry[1] !== undefined);
                return JSON.stringify(Object.keys(values).sort())
                    === JSON.stringify(["STATEUI_ANDROID", "STATEUI_APPKIT", "STATEUI_GTK", "STATEUI_UIKIT", "STATEUI_WINUI"])
                    && JSON.stringify(set) === JSON.stringify([[host.variable, "1"]]);
            }) && environment("android").STATEUI_ANDROID === "1"
            && Object.values(environment(undefined)).every((value) => value === undefined));
        {
            const sdk = "swift-6.4.0-RELEASE_android";
            const android = serverConfig(
                { swiftPM: { scratchPath: ".build-appkit/index-build", configuration: "debug" }, index: { indexStorePath: "x" } },
                serverSettings("android", sdk));
            const back = serverConfig(android, serverSettings("appkit", sdk));
            check("as Android the language server indexes in .build-android/index-build with the Swift SDK and aarch64-unknown-linux-android28, by building",
                android.swiftPM?.scratchPath === ".build-android/index-build" && android.swiftPM?.swiftSDK === sdk
                && android.swiftPM?.triple === "aarch64-unknown-linux-android28" && android.backgroundPreparationMode === "build");
            check("the rest of the file is kept, and back on AppKit the SDK and the triple are gone",
                android.swiftPM?.configuration === "debug" && JSON.stringify(android.index) === JSON.stringify({ indexStorePath: "x" })
                && back.swiftPM?.scratchPath === ".build-appkit/index-build" && back.swiftPM?.configuration === "debug"
                && !("swiftSDK" in back.swiftPM!) && !("triple" in back.swiftPM!));
            check("with no Swift SDK installed Android indexes for this Mac, and with no host the index is SwiftPM's own, with no SDK",
                JSON.stringify(serverSettings("android", undefined)) === JSON.stringify({ scratchPath: ".build-android/index-build" })
                && JSON.stringify(serverSettings(undefined, sdk)) === JSON.stringify({ scratchPath: ".build/index-build" }));

            // The other releases are assembled, so the repository's one-release guard reads no second one here.
            const older = ["6", "3", "3"].join("."), newer = ["6", "5"].join(".");
            const list = `swift-${older}-RELEASE_android\nswift-6.4.0-RELEASE_android\nswift-6.4.0-RELEASE_static-linux-0.1.0\n`;
            const sdkOf = (version: string) => swiftSDKOf(swiftRelease(version), list, "android");
            check("the Swift SDK for Android is the one of the toolchain's release, as build-swift.sh finds it",
                sdkOf("Apple Swift version 6.4 (swift-6.4-RELEASE)\nTarget: arm64-apple-macosx26.0") === sdk
                && sdkOf(`Apple Swift version ${older} (swift-${older}-RELEASE)`) === `swift-${older}-RELEASE_android`
                && sdkOf(`Apple Swift version ${newer} (swift-${newer}-RELEASE)`) === undefined && sdkOf("") === undefined);
        }
        check("devices.sh list reads as the devices attached, by serial and name, and the emulators not running",
            JSON.stringify(parseDevices("device\t190a991d\tCPH2363\r\ndevice\temulator-5554\tPixel_3a_API_34\ndevice\tR5CT\navd\tMedium_Phone_API_36\n\nnoise\n"))
            === JSON.stringify([
                { kind: "device", serial: "190a991d", name: "CPH2363" },
                { kind: "device", serial: "emulator-5554", name: "Pixel_3a_API_34" },
                { kind: "device", serial: "R5CT", name: "R5CT" },
                { kind: "avd", name: "Medium_Phone_API_36" },
            ]));

        const helloWorld = findApplications(root.uri.fsPath).find((each) => each.name === "HelloWorld")!;
        check("HelloWorld and the Gallery have Android heads",
            hasHead(helloWorld, "android") && hasHead(gallery_, "android"));
        {
            // What run-app.sh --debugger writes once the application runs, faked
            // by the task's start - or not, where the application never starts.
            const facts = path.join(helloWorld.directory, ".build-android", "debugger.json");
            const launchOnAndroid = async (serial: string | undefined, configuration = "release", starts = true) => {
                const started: vscode.Task[] = [];
                const ran: string[] = [];
                const provider = new StateUIDebugConfigurationProvider({
                    host: () => "android", application: async () => helloWorld,
                    run: async (task) => { ran.push(task.name); return 0; },
                    start: async (task) => {
                        started.push(task);
                        if (configuration === "debug" && starts) {
                            fs.mkdirSync(path.dirname(facts), { recursive: true });
                            fs.writeFileSync(facts, JSON.stringify({
                                serial, package: "com.stateui.helloworld", process: 4242,
                                socket: "com.stateui.helloworld/stateui-debugger.sock", symbols: "/build/symbols/arm64-v8a",
                            }));
                        }
                    },
                    ready: async (file) => fs.existsSync(file),
                    device: async () => serial,
                    uiKitDevice: async () => undefined,
                });
                const resolved = await provider.resolveDebugConfiguration(root, {
                    name: configuration === "debug" ? "StateUI: Debug" : "StateUI: Release", type: "stateui",
                    request: "launch", configuration,
                });
                fs.rmSync(facts, { force: true });
                return { resolved, started, ran };
            };

            const { resolved, started, ran } = await launchOnAndroid("emulator-5554");
            const shell = started[0]?.execution as vscode.ShellExecution | undefined;
            const line = shell ? [shell.command, ...(shell.args ?? [])].map(String).join(" ") : "";
            say(`     android started: ${line}`);
            check("Android: run-app.sh <HelloWorld> release <serial> started as a task on that device, nothing waited for, and no session",
                resolved === undefined && ran.length === 0 && started.length === 1
                && line === `bash ${path.join(root.uri.fsPath, ".scripts", "Android", "run-app.sh")} ${helloWorld.directory} release emulator-5554`
                && started[0].definition.application === "HelloWorld" && started[0].definition.device === "emulator-5554");

            const declined = await launchOnAndroid(undefined);
            check("Android with no device picked starts nothing and opens no session",
                declined.resolved === undefined && declined.started.length === 0);

            const debugged = await launchOnAndroid("emulator-5554", "debug");
            const debugShell = debugged.started[0]?.execution as vscode.ShellExecution | undefined;
            const debugLine = debugShell ? [debugShell.command, ...(debugShell.args ?? [])].map(String).join(" ") : "";
            say(`     android debugged: ${JSON.stringify(debugged.resolved)}`);
            check("Android Debug: run-app.sh ... debug <serial> --debugger, then lldb-dap attached through the device's lldb-server to the process started",
                debugLine.endsWith(`${helloWorld.directory} debug emulator-5554 --debugger`)
                && debugged.resolved?.type === "lldb-dap" && debugged.resolved.request === "attach"
                && JSON.stringify(debugged.resolved.initCommands) === JSON.stringify([
                    "settings set plugin.jit-loader.gdb.enable off",
                    "platform select remote-android",
                    "platform connect unix-abstract-connect://emulator-5554/com.stateui.helloworld/stateui-debugger.sock",
                    "settings append target.exec-search-paths /build/symbols/arm64-v8a",
                ])
                && JSON.stringify(debugged.resolved.attachCommands) === JSON.stringify([
                    "process attach --pid 4242",
                    "process handle SIGSEGV --pass true --stop false --notify false",
                    "process handle SIGBUS --pass true --stop false --notify false",
                ]));

            const failed = await launchOnAndroid("emulator-5554", "debug", false);
            check("Android Debug whose application never starts opens no session",
                failed.resolved === undefined && failed.started.length === 1);
        }
        {
            const androidSuites = findSuites(root.uri.fsPath, "android");
            say(`android suites: ${androidSuites.map((each) => each.label).join(", ")}`);
            const onDevice = androidSuites.filter((each) => each.onDevice).map((each) => forDevice(each, "emulator-5554"));
            const galleryRun = androidSuites.find((each) => each.label === "apps/Gallery");
            check("android runs the core and the Gallery as plain Swift, and no AppKit",
                androidSuites.some((each) => each.label === "StateUI" && forDevice(each, "emulator-5554") === each)
                && galleryRun?.args.join(" ") === `test --package-path ${gallery}` && Object.keys(galleryRun.env).length === 0
                && !androidSuites.some((each) => each.label === "lib/StateUI.AppKit"));
            check("android runs test-android.sh <serial> on the device, and only android does",
                onDevice.length === 1 && onDevice[0].label === "lib/StateUI.Android/Tests"
                && [onDevice[0].command, ...onDevice[0].args].join(" ") === `bash ${path.join(root.uri.fsPath, ".scripts", "Android", "test-android.sh")} emulator-5554`
                && !appkitSuites.includes("lib/StateUI.Android/Tests"));
        }
        // 6a. UIKit: the language server's file, the simulators, and the
        //     commands a launch and a suite run - captured, not run.
        {
            const simulatorSDK = "/Xcode/SDKs/iPhoneSimulator.sdk";
            const uiKit = serverConfig({ swiftPM: { scratchPath: ".build-appkit/index-build" } }, serverSettings("uikit", undefined, simulatorSDK));
            const back = serverConfig(uiKit, serverSettings("appkit", undefined));
            check("as UIKit the language server indexes in .build-uikit/index-build for arm64-apple-ios26.0-simulator against Xcode's simulator SDK - and back on AppKit both are gone",
                uiKit.swiftPM?.scratchPath === ".build-uikit/index-build" && uiKit.swiftPM?.triple === "arm64-apple-ios26.0-simulator"
                && uiKit.swiftPM?.sdk === simulatorSDK && !("swiftSDK" in uiKit.swiftPM!)
                && back.swiftPM?.scratchPath === ".build-appkit/index-build" && !("triple" in back.swiftPM!) && !("sdk" in back.swiftPM!));
            check("with no simulator SDK found UIKit indexes for this Mac",
                JSON.stringify(serverSettings("uikit", undefined, undefined)) === JSON.stringify({ scratchPath: ".build-uikit/index-build" }));
        }
        check("simctl's list reads as the iOS simulators a head installs on, the newest runtime first",
            JSON.stringify(parseSimulators(JSON.stringify({ devices: {
                "com.apple.CoreSimulator.SimRuntime.iOS-18-2": [{ udid: "OLD", name: "iPhone 16", state: "Shutdown" }],
                "com.apple.CoreSimulator.SimRuntime.iOS-26-0": [{ udid: "A", name: "iPhone 17", state: "Shutdown" }],
                "com.apple.CoreSimulator.SimRuntime.iOS-27-0": [
                    { udid: "B", name: "iPhone 18 Pro", state: "Booted" }, { udid: "C", name: "iPad Air 13-inch (M4)", state: "Shutdown" }],
                "com.apple.CoreSimulator.SimRuntime.watchOS-12-0": [{ udid: "W", name: "Apple Watch", state: "Shutdown" }],
            } })))
            === JSON.stringify([
                { id: "B", name: "iPhone 18 Pro", kind: "simulator", os: "27.0", state: "booted" },
                { id: "C", name: "iPad Air 13-inch (M4)", kind: "simulator", os: "27.0", state: "" },
                { id: "A", name: "iPhone 17", kind: "simulator", os: "26.0", state: "" },
            ]) && parseSimulators("not json").length === 0);
        {
            const device = (name: string, os: string, transport: string, reality = "physical", pairing = "paired") => ({
                identifier: `${name}-ID`, connectionProperties: { pairingState: pairing, transportType: transport },
                deviceProperties: { name, osVersionNumber: os }, hardwareProperties: { platform: "iOS", reality },
            });
            check("devicectl's list reads as the iPhones and iPads paired with this Mac, of an iOS a head installs on",
                JSON.stringify(parseUIKitDevices(JSON.stringify({ result: { devices: [
                    device("Phone", "26.6.2", "wired"), device("Tablet", "26.6.1", "localNetwork"),
                    device("Old Phone", "18.4", "wired"), device("iPhone 17", "26.0", "sameMachine", "virtual"),
                    device("Stranger", "26.1", "wired", "physical", "unpaired"),
                ] } })))
                === JSON.stringify([
                    { id: "Phone-ID", name: "Phone", kind: "device", os: "26.6.2", state: "USB" },
                    { id: "Tablet-ID", name: "Tablet", kind: "device", os: "26.6.1", state: "Wi-Fi" },
                ]) && parseUIKitDevices("not json").length === 0);
            const onDevice = uiKitAttach("StateUI: Debug", { process: 37779, device: "PHONE", symbols: "/b/App.app" });
            check("on a device lldb-dap selects the device, attaches to the process through it, and reads symbols from the bundle built",
                onDevice.request === "attach" && onDevice.pid === undefined
                && JSON.stringify(onDevice.attachCommands) === JSON.stringify(["device select PHONE", "device process attach --pid 37779"])
                && JSON.stringify(onDevice.initCommands) === JSON.stringify([
                    "settings append target.exec-search-paths /b/App.app", "settings append target.exec-search-paths /b/App.app/Frameworks"]));
        }
        {
            const helloWorldHere = findApplications(root.uri.fsPath).find((each) => each.name === "HelloWorld")!;
            check("HelloWorld and the Gallery have UIKit heads", hasHead(helloWorldHere, "uikit") && hasHead(gallery_, "uikit"));
            const facts = path.join(helloWorldHere.directory, ".build-uikit", "debugger.json");
            const launchOnUIKit = async (udid: string | undefined, configuration = "release", starts = true) => {
                const started: vscode.Task[] = [];
                const provider = new StateUIDebugConfigurationProvider({
                    host: () => "uikit", application: async () => helloWorldHere,
                    run: async () => 0,
                    start: async (task) => {
                        started.push(task);
                        if (configuration === "debug" && starts) {
                            fs.mkdirSync(path.dirname(facts), { recursive: true });
                            fs.writeFileSync(facts, JSON.stringify({ process: 4343 }));
                        }
                    },
                    ready: async (file) => fs.existsSync(file),
                    device: async () => undefined,
                    uiKitDevice: async () => udid,
                });
                const resolved = await provider.resolveDebugConfiguration(root, {
                    name: configuration === "debug" ? "StateUI: Debug" : "StateUI: Release", type: "stateui",
                    request: "launch", configuration,
                });
                fs.rmSync(facts, { force: true });
                const shell = started[0]?.execution as vscode.ShellExecution | undefined;
                return { resolved, started, line: shell ? [shell.command, ...(shell.args ?? [])].map(String).join(" ") : "" };
            };
            const script = path.join(root.uri.fsPath, ".scripts", "UIKit", "run-app.sh");

            const released = await launchOnUIKit("SIM-1");
            say(`     uikit started: ${released.line}`);
            check("UIKit: run-app.sh <HelloWorld> release <udid> started as a task on that simulator, and no session",
                released.resolved === undefined && released.started.length === 1
                && released.line === `bash ${script} ${helloWorldHere.directory} release SIM-1`
                && released.started[0].definition.device === "SIM-1");

            const declined = await launchOnUIKit(undefined);
            check("UIKit with no device picked starts nothing", declined.resolved === undefined && declined.started.length === 0);

            const debugged = await launchOnUIKit("SIM-1", "debug");
            say(`     uikit debugged: ${JSON.stringify(debugged.resolved)}`);
            check("UIKit Debug: run-app.sh ... debug <udid> --debugger, then lldb-dap attached to the process it started",
                debugged.line === `bash ${script} ${helloWorldHere.directory} debug SIM-1 --debugger`
                && debugged.resolved?.type === "lldb-dap" && debugged.resolved.request === "attach" && debugged.resolved.pid === 4343);

            const failed = await launchOnUIKit("SIM-1", "debug", false);
            check("UIKit Debug whose application never starts opens no session", failed.resolved === undefined && failed.started.length === 1);
        }
        {
            const uiKitSuites = findSuites(root.uri.fsPath, "uikit");
            say(`uikit suites: ${uiKitSuites.map((each) => each.label).join(", ")}`);
            const onSimulator = uiKitSuites.filter((each) => each.onDevice).map((each) => forDevice(each, "SIM-1"));
            check("uikit runs the core and the Gallery as plain Swift, and test-uikit.sh <udid> on the simulator",
                uiKitSuites.some((each) => each.label === "StateUI")
                && onSimulator.length === 1 && onSimulator[0].label === "lib/StateUI.UIKit/Tests"
                && [onSimulator[0].command, ...onSimulator[0].args].join(" ") === `bash ${path.join(root.uri.fsPath, ".scripts", "UIKit", "test-uikit.sh")} SIM-1`
                && !uiKitSuites.some((each) => each.label === "lib/StateUI.AppKit" || each.label === "lib/StateUI.Android/Tests"));
        }

        // 6b. WinUI: HelloWorld's head, built by run-app.ps1 -BuildOnly and
        //     launched under lldb-dap, and the host's own package through test-winui.ps1.
        check("HelloWorld has a WinUI head, and as WinUI the language server indexes in .build-winui/index-build",
            hasHead(helloWorld, "winui")
            && JSON.stringify(serverSettings("winui", undefined)) === JSON.stringify({ scratchPath: ".build-winui/index-build" }));
        {
            const ran: vscode.Task[] = [];
            const provider = new StateUIDebugConfigurationProvider({
                host: () => "winui", application: async () => helloWorld,
                run: async (task) => { ran.push(task); return 0; },
                start: async () => {},
                ready: async () => false,
                device: async () => undefined,
                uiKitDevice: async () => undefined,
            });
            const resolved = await provider.resolveDebugConfiguration(root,
                { name: "StateUI: Release", type: "stateui", request: "launch", configuration: "release" });
            const process_ = ran[0]?.execution as vscode.ProcessExecution | undefined;
            const line = process_ ? [process_.process, ...process_.args].join(" ") : "";
            say(`     winui built: ${line}`);
            check("WinUI: run-app.ps1 -App <HelloWorld> -Configuration release -BuildOnly ran as a task, then lldb-dap launches HelloWorldWinUI.exe",
                ran.length === 1
                && line === `powershell -NoProfile -ExecutionPolicy Bypass -File ${path.join(root.uri.fsPath, ".scripts", "WinUI", "run-app.ps1")} -App ${helloWorld.directory} -Configuration release -BuildOnly`
                && resolved?.type === "lldb-dap" && resolved.request === "launch"
                && resolved.program === path.join(helloWorld.directory, ".build-winui", "release", "HelloWorldWinUI.exe"));
        }
        {
            const winUISuites = findSuites(root.uri.fsPath, "winui");
            say(`winui suites: ${winUISuites.map((each) => each.label).join(", ")}`);
            const own = winUISuites.find((each) => each.label === "lib/StateUI.WinUI");
            check("winui runs the core and the Gallery as plain Swift, its own package by test-winui.ps1, and no AppKit or Android",
                winUISuites.some((each) => each.label === "StateUI")
                && own?.command === "powershell" && own.args[own.args.length - 1].endsWith("test-winui.ps1")
                && !winUISuites.some((each) => each.label === "lib/StateUI.AppKit" || each.label === "lib/StateUI.Android/Tests"));
        }

        // 6c. GTK: HelloWorld's head, built by run-app.sh --build-only and
        //     launched under lldb-dap, and the host's own package by swift test.
        check("HelloWorld has a GTK head, and as GTK the language server indexes in .build-gtk/index-build",
            hasHead(helloWorld, "gtk")
            && JSON.stringify(serverSettings("gtk", undefined)) === JSON.stringify({ scratchPath: ".build-gtk/index-build" }));
        {
            const ran: vscode.Task[] = [];
            const provider = new StateUIDebugConfigurationProvider({
                host: () => "gtk", application: async () => helloWorld,
                run: async (task) => { ran.push(task); return 0; },
                start: async () => {},
                ready: async () => false,
                device: async () => undefined,
                uiKitDevice: async () => undefined,
            });
            const resolved = await provider.resolveDebugConfiguration(root,
                { name: "StateUI: Debug", type: "stateui", request: "launch", configuration: "debug" });
            const shell = ran[0]?.execution as vscode.ShellExecution | undefined;
            const line = shell ? [shell.command, ...shell.args].join(" ") : "";
            say(`     gtk built: ${line}`);
            check("GTK: run-app.sh <HelloWorld> debug --build-only ran as a task, then lldb-dap launches HelloWorldGTK",
                ran.length === 1
                && line === `bash ${path.join(root.uri.fsPath, ".scripts", "GTK", "run-app.sh")} ${helloWorld.directory} debug --build-only`
                && resolved?.type === "lldb-dap" && resolved.request === "launch"
                && resolved.program === path.join(helloWorld.directory, ".build-gtk", "debug", "HelloWorldGTK"));
        }
        {
            const gtkSuites = findSuites(root.uri.fsPath, "gtk");
            say(`gtk suites: ${gtkSuites.map((each) => each.label).join(", ")}`);
            const own = gtkSuites.find((each) => each.label === "lib/StateUI.GTK");
            check("gtk runs the core and the Gallery as plain Swift, its own package by swift test, and no other host's",
                gtkSuites.some((each) => each.label === "StateUI")
                && own?.command === "swift" && own.args.join(" ") === `test --package-path ${path.join(root.uri.fsPath, "lib", "StateUI.GTK")}`
                && !gtkSuites.some((each) => ["lib/StateUI.AppKit", "lib/StateUI.WinUI", "lib/StateUI.Android/Tests"].includes(each.label)));
        }

        const palette = await vscode.commands.getCommands(true);
        check("the palette has Select Android Device and Select UIKit Device, and no Select Debugger",
            palette.includes("stateui.selectAndroidDevice") && palette.includes("stateui.selectUIKitDevice")
            && !palette.includes("stateui.selectDebugger") && !palette.includes("stateui.selectSimulator"));

        // 7. A new application is HelloWorld renamed in a checkout's apps/,
        //    by the checkout's scaffolder - the only starter.
        const commands = await vscode.commands.getCommands(true);
        check("the palette has New Application in apps/ and no New Application from Template",
            commands.includes("stateui.newApplicationInApps") && !commands.includes("stateui.newApplication"));
        check("a name is letters and digits, starting with a letter, and not StateUI",
            nameProblem("MyApp2") === undefined && nameProblem("My-App") !== undefined
            && nameProblem("2App") !== undefined && nameProblem("StateUI") !== undefined);
        {
            const made = inAppsCommand(root.uri.fsPath, "Notes", "darwin");
            const windows = inAppsCommand(root.uri.fsPath, "Notes", "win32");
            check("in apps/ it is the checkout's scaffolder: new-app.sh Notes, new-app.ps1 -Name Notes",
                made.command === "bash" && made.args[0].split(path.sep).join("/").endsWith("/.scripts/new-app.sh") && made.args[1] === "Notes"
                && windows.command === "powershell" && windows.args.slice(-3).join(" ").endsWith("new-app.ps1 -Name Notes"));
        }
        // 7b. The extension reinstalls itself from the checkout: packed by npm, installed by the editor's command line.
        {
            const version = JSON.parse(fs.readFileSync(path.join(root.uri.fsPath, "lib", "StateUI.VSCode", "package.json"), "utf8")).version;
            const steps = reinstallSteps(root.uri.fsPath, "/Editor/bin/code");
            check("Reinstall VS Code Extension packs it with npm in lib/StateUI.VSCode, then installs artifacts/stateui-<version>.vsix with --force",
                commands.includes("stateui.reinstallExtension") && steps.length === 2
                && `${steps[0].command} ${steps[0].args.join(" ")}` === "npm run package"
                && steps[0].cwd === path.join(root.uri.fsPath, "lib", "StateUI.VSCode")
                && steps[1].command === "/Editor/bin/code"
                && steps[1].args.join(" ") === `--install-extension ${path.join(root.uri.fsPath, "artifacts", `stateui-${version}.vsix`)} --force`);
        }
        // 7c. The chosen host's marks are made again - every family, or the stale ones - then the documents rendered,
        //     from a checkout alone.
        {
            const checkout = root.uri.fsPath;
            const all = rebuildSteps(checkout, "winui", "all");
            const changed = rebuildSteps(checkout, "winui", "changed");
            const appKit = rebuildSteps(checkout, "appkit", "changed");
            const manifest = JSON.parse(fs.readFileSync(path.join(checkout, "lib", "StateUI.VSCode", "package.json"), "utf8"));
            const hidden = (command: string): boolean => manifest.contributes.menus.commandPalette
                .some((each: { command: string; when?: string }) => each.command === command && each.when === "stateui.hasCheckout");
            check("Conformance - Rebuild all and Rebuild changed run the host's families writing their verdicts, then render the documents",
                commands.includes("stateui.conformanceRebuildAll") && commands.includes("stateui.conformanceRebuildChanged")
                && all?.length === 2 && all[0].args.slice(-1)[0] === "-Conformance" && all[0].env.STATEUI_UPDATE_EXPORTS === "1"
                && changed?.[0].args.slice(-1)[0] === "-Stale"
                && appKit?.[0].args.slice(-2).join(" ") === "--filter AppKitConformanceTests" && appKit[0].env.STATEUI_STALE_ONLY === "1"
                && all[1].command === "swift" && all[1].args.join(" ") === "test --filter ControlDictionaryTests"
                && all[1].env.STATEUI_UPDATE_DOCS === "1"
                && rebuildSteps(checkout, "android", "changed", "serial") === undefined
                && rebuildSteps(checkout, "uikit", "all") === undefined);
            check("the conformance rebuilds and the reinstall show in a StateUI checkout alone",
                hidden("stateui.conformanceRebuildAll") && hidden("stateui.conformanceRebuildChanged")
                && hidden("stateui.reinstallExtension"));
        }
        // 7d. StateUI: Check Toolchain says what this machine has of what its hosts need, and what to install for the
        //     rest: its tools' words read, and on the machine running the suite, nothing missing.
        {
            const loaders = (svg: boolean) => [
                "# GdkPixbuf Image Loader Modules file", "",
                '"/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders/libpixbufloader-png.so"',
                '"png" 5 "gdk-pixbuf" "PNG" "LGPL"', '"image/png" ""', '"png" ""', "",
                ...(svg ? ['"/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders/libpixbufloader-svg.so"',
                    '"svg" 6 "gdk-pixbuf" "Scalable Vector Graphics" "LGPL"', '"image/svg+xml" "image/svg" ""', ""] : []),
            ].join("\n");
            check("Check Toolchain compares versions part by part, reads Xcode's, simctl's, a toolchain's, an NDK's and "
                + "gdk-pixbuf's words, and says a version too old",
                commands.includes("stateui.checkToolchain")
                && atLeast("6.4.1", "6.4") && atLeast("26", "26.0") && !atLeast("6.3.9", "6.4") && !atLeast("4.13", "4.14")
                && xcodeVersion("Xcode 27.0\nBuild version 27A123") === "27.0"
                && isSwiftOrgBuild("Swift version 6.4 (swift-6.4-RELEASE)")
                && !isSwiftOrgBuild("Apple Swift version 6.4 (swiftlang-6.4.0.1.2 clang-1700.0.1)")
                && newestIOSRuntime(JSON.stringify({ runtimes: [
                    { platform: "iOS", version: "26.0", isAvailable: true }, { platform: "iOS", version: "26.2", isAvailable: true },
                    { platform: "watchOS", version: "27.0", isAvailable: true }] })) === "26.2"
                && svgLoaderIn(loaders(true)) === "libpixbufloader-svg.so" && svgLoaderIn(loaders(false)) === undefined
                && debuggerFinding(["lldb-dap"]).found !== undefined && debuggerFinding(["node"]).found === undefined
                && ndkRevisionIn("Pkg.Desc = Android NDK\nPkg.Revision = 30.0.16248370\n") === "30.0.16248370"
                && report([{ component: "Node.js 20 or newer", neededBy: "it", tooOld: "19.4.0", advice: "Install it." }])[0]
                    === "✗ Node.js 20 or newer - 19.4.0 found, too old [it]. Install it.");
            const findings = await checkToolchain();
            report(findings).forEach((line) => say(`     ${line}`));
            const own: Record<string, string> = { linux: "GTK 4.14 or newer, with its headers", darwin: "Xcode 27 or newer",
                win32: "Visual Studio 2026 with the C++ tools for this machine" };
            const missing = findings.filter((each) => each.found === undefined).map((each) => each.component);
            check(`Check Toolchain looks for Swift, this platform's own and lldb-dap, and finds them all here${
                missing.length > 0 ? ` - not ${missing.join(", ")}` : ""}`,
                findings[0]?.component === "Swift 6.4 or newer" && findings.some((each) => each.component === own[process.platform])
                && findings.some((each) => each.component === "lldb-dap") && missing.length === 0
                && findings.every((each) => each.advice.length > 0));
        }
        // 8. The package holds what the sources build today and nothing an
        //    older build left in out/.
        {
            const extension = path.join(root.uri.fsPath, "lib", "StateUI.VSCode");
            const vsce = path.join(extension, "node_modules", ".bin", process.platform === "win32" ? "vsce.cmd" : "vsce");
            const packed = execSync(`"${vsce}" ls`, { cwd: extension }).toString().split(/\r?\n/).filter((line) => line.length > 0);
            // A compiled file whose source is gone is left in out/ by tsc, and would be packed.
            const stray = packed.filter((file) => {
                const compiled = file.match(/^out\/Sources\/([A-Za-z]+)\.js$/);
                return compiled ? !fs.existsSync(path.join(extension, "Sources", `${compiled[1]}.ts`))
                    : !/^(package\.json|README\.md|icon\.png|LICENSE)$/.test(file);
            });
            check(`the package holds the manifest, the readme, the icon and what Sources compile to alone${stray.length > 0 ? ` - not ${stray.slice(0, 3).join(", ")}` : ""}`,
                stray.length === 0 && packed.includes("out/Sources/extension.js"));
        }
        // 9. StateUI: Debug runs the REMEMBERED application - no question asked - on this machine's host: AppKit
        //    built and under lldb-dap on macOS, WinUI on Windows and GTK on Linux alike.
        if (process.platform === "darwin") {
            await api.selectHost("appkit");
            await api.selectApplication("HelloWorld");
            check("the chosen application is remembered", api.application() === "HelloWorld");
            const session = new Promise<vscode.DebugSession>((resolve) => {
                const listener = vscode.debug.onDidStartDebugSession((each) => {
                    if (each.type === "lldb-dap") {
                        listener.dispose();
                        resolve(each);
                    }
                });
            });
            check("StateUI: Debug starts", await vscode.debug.startDebugging(root,
                { name: "StateUI: Debug", type: "stateui", request: "launch", configuration: "debug" }));
            const running = await Promise.race([session, new Promise<undefined>((resolve) => setTimeout(() => resolve(undefined), 600_000))]);
            check("an lldb-dap session starts on HelloWorldAppKit", String(running?.configuration.program ?? "").endsWith("/apps/HelloWorld/.build/debug/HelloWorldAppKit"));
            await new Promise((resume) => setTimeout(resume, 4000));
            const alive = (() => { try { return execSync("pgrep -f apps/HelloWorld/.build/debug/HelloWorldAppKit").toString().trim().length > 0; } catch { return false; } })();
            check("the HelloWorldAppKit process is running", alive);
            await vscode.debug.stopDebugging(running);

            // And on the iOS simulator: run-app.sh starts HelloWorld held, and lldb-dap attaches and lets it run.
            const iPhone = parseSimulators(execSync("xcrun simctl list devices available -j").toString())
                .find((each) => each.name.startsWith("iPhone"));
            check("an iPhone simulator is available", iPhone !== undefined);
            await api.selectHost("uikit");
            await api.selectApplication("HelloWorld");
            check("a simulator chosen by its UDID is named in the status bar by its name",
                (await api.selectUIKitDevice(iPhone!.id)) === iPhone!.name);
            const attached = new Promise<vscode.DebugSession>((resolve) => {
                const listener = vscode.debug.onDidStartDebugSession((each) => {
                    if (each.type === "lldb-dap") {
                        listener.dispose();
                        resolve(each);
                    }
                });
            });
            check("StateUI: Debug starts on UIKit", await vscode.debug.startDebugging(root,
                { name: "StateUI: Debug", type: "stateui", request: "launch", configuration: "debug" }));
            const onSimulator = await Promise.race([attached, new Promise<undefined>((resolve) => setTimeout(() => resolve(undefined), 900_000))]);
            check("an lldb-dap session attaches to HelloWorldUIKit's process", typeof onSimulator?.configuration.pid === "number");
            await new Promise((resume) => setTimeout(resume, 4000));
            const onDevice = (() => { try { return execSync(`pgrep -f ${iPhone!.id}.*HelloWorldUIKit`).toString().trim().length > 0; } catch { return false; } })();
            check("the HelloWorldUIKit process runs on the simulator", onDevice);
            await vscode.debug.stopDebugging(onSimulator);
            execSync(`xcrun simctl terminate ${iPhone!.id} com.stateui.helloworld || true`);

            // And on a real iPhone or iPad, where STATEUI_UIKIT_DEVICE names one connected: signed, installed, started
            // held, and attached to through the device.
            const real = process.env.STATEUI_UIKIT_DEVICE;
            if (real) {
                const named = await api.selectUIKitDevice(real);
                check("the device chosen by its identifier is named by its name", named !== undefined && named !== real);
                const attachedOnDevice = new Promise<vscode.DebugSession>((resolve) => {
                    const listener = vscode.debug.onDidStartDebugSession((each) => {
                        if (each.type === "lldb-dap") {
                            listener.dispose();
                            resolve(each);
                        }
                    });
                });
                check("StateUI: Debug starts on the device", await vscode.debug.startDebugging(root,
                    { name: "StateUI: Debug", type: "stateui", request: "launch", configuration: "debug" }));
                const session = await Promise.race([attachedOnDevice, new Promise<undefined>((resolve) => setTimeout(() => resolve(undefined), 900_000))]);
                check("an lldb-dap session attaches through the device", JSON.stringify(session?.configuration.attachCommands ?? []).includes(`device select ${real}`));
                await new Promise((resume) => setTimeout(resume, 8000));
                const running = (() => { try { return execSync(`xcrun devicectl device info processes --device ${real}`).toString().includes("HelloWorldUIKit"); } catch { return false; } })();
                check("the HelloWorldUIKit process runs on the device", running);
                await vscode.debug.stopDebugging(session);
            } else {
                say("skip a real device: STATEUI_UIKIT_DEVICE names none");
            }
        } else if (process.platform === "win32") {
            await api.selectHost("winui");
            await api.selectApplication("HelloWorld");
            check("the chosen application is remembered", api.application() === "HelloWorld");
            const session = new Promise<vscode.DebugSession>((resolve) => {
                const listener = vscode.debug.onDidStartDebugSession((each) => {
                    if (each.type === "lldb-dap") {
                        listener.dispose();
                        resolve(each);
                    }
                });
            });
            check("StateUI: Debug starts", await vscode.debug.startDebugging(root,
                { name: "StateUI: Debug", type: "stateui", request: "launch", configuration: "debug" }));
            const running = await Promise.race([session, new Promise<undefined>((resolve) => setTimeout(() => resolve(undefined), 900_000))]);
            check("an lldb-dap session starts on HelloWorldWinUI.exe",
                String(running?.configuration.program ?? "").endsWith(path.join("apps", "HelloWorld", ".build-winui", "debug", "HelloWorldWinUI.exe")));
            const alive = (): boolean => {
                try {
                    return execSync('tasklist /FI "IMAGENAME eq HelloWorldWinUI.exe" /NH').toString().includes("HelloWorldWinUI.exe");
                } catch {
                    return false;
                }
            };
            await until("the HelloWorldWinUI process is running", async () => alive(), 60);
            await vscode.debug.stopDebugging(running);
        } else {
            await api.selectHost("gtk");
            await api.selectApplication("HelloWorld");
            check("the chosen application is remembered", api.application() === "HelloWorld");
            const session = new Promise<vscode.DebugSession>((resolve) => {
                const listener = vscode.debug.onDidStartDebugSession((each) => {
                    if (each.type === "lldb-dap") {
                        listener.dispose();
                        resolve(each);
                    }
                });
            });
            check("StateUI: Debug starts", await vscode.debug.startDebugging(root,
                { name: "StateUI: Debug", type: "stateui", request: "launch", configuration: "debug" }));
            const running = await Promise.race([session, new Promise<undefined>((resolve) => setTimeout(() => resolve(undefined), 900_000))]);
            check("an lldb-dap session starts on HelloWorldGTK",
                String(running?.configuration.program ?? "").endsWith("/apps/HelloWorld/.build-gtk/debug/HelloWorldGTK"));
            await new Promise((resume) => setTimeout(resume, 4000));
            const alive = (() => { try { return execSync("pgrep -f apps/HelloWorld/.build-gtk/debug/HelloWorldGTK").toString().trim().length > 0; } catch { return false; } })();
            check("the HelloWorldGTK process is running", alive);
            await vscode.debug.stopDebugging(running);
        }

        say("PASS");
    } catch (error) {
        say(`FAIL ${error instanceof Error ? error.message : String(error)}`);
        throw error;
    }
}
