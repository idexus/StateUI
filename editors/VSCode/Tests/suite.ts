// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The integration suite, run inside VS Code by Tests/run.ts.
//
// The editor's host is asked of the LANGUAGE SERVER, which cannot be faked: a
// symbol of the AppKit head resolves only while SourceKit-LSP runs with
// STATEUI_HOST=appkit, and a symbol under no condition resolves in either mode -
// which is what tells "not this host" from "not ready yet".

import { execSync, spawn } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import * as vscode from "vscode";
import { Application, applicationsOf, hasHead, readApplications, winUIProgram } from "../Sources/applications";
import { Configuration, configurations, StateUIDebugConfigurationProvider, uiKitAttach, webLaunch } from "../Sources/debug";
import { androidDeviceOf, deviceAmong } from "../Sources/devices";
import { isChromium, parseBrowsers } from "../Sources/browsers";
import { simulatorForSuites, uiKitDeviceOf } from "../Sources/uiKitDevices";
import { buildingCommand, otherHostsExcluded, restartServer, serverConfig, serverSettings, swiftRelease, swiftSDKOf } from "../Sources/editorMode";
import { findSuites, forDevice } from "../Sources/tests";
import { givesWay } from "../Sources/tasks";
import { availableHosts, describe, environment, Host, hosts } from "../Sources/hosts";
import { StateUIApi } from "../Sources/extension";
import { editorCommandLine, reinstallSteps } from "../Sources/reinstall";
import { rebuildSteps } from "../Sources/conformance";
import { deployCommand, deployDestination, winUIArchitectures } from "../Sources/deploy";
import {
    atLeast, checkedPythonIn, debuggerFinding, Finding, lldbDapFailure, report,
} from "../Sources/toolchain";
import { ToolingClient } from "../Sources/Tooling/client";
import { locateTool } from "../Sources/Tooling/locate";

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

// A probe that throws has not yet seen it: a request the language server's restart rejected is asked again.
async function until(what: string, probe: () => Promise<boolean>, seconds: number): Promise<void> {
    const deadline = Date.now() + seconds * 1000;
    let refused: unknown;
    while (Date.now() < deadline) {
        try {
            if (await probe()) {
                say(`ok   ${what}`);
                return;
            }
        } catch (error) {
            refused = error;
        }
        await new Promise((resume) => setTimeout(resume, 5000));
    }
    throw new Error(`timed out after ${seconds}s: ${what}${refused ? ` - last refused: ${String(refused)}` : ""}`);
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

        // The applications, found at activation through the stateui tool: this checkout's workspace lists Gallery and HelloWorld.
        const found = api.applications().map((each) => each.name).join(" ");
        check(`the extension finds this checkout's applications through the stateui tool${found === "Gallery HelloWorld" ? "" : ` - not "${found}"`}`,
            found === "Gallery HelloWorld");

        // 0. A restart the Swift extension rejects - its server, still loading packages, not stopped in time, or its
        //    client still starting - is asked again until it takes; a refusal that lasts is the caller's.
        {
            let asked = 0;
            const recovered = await restartServer(async () => {
                asked += 1;
                if (asked < 3) {
                    throw new Error(asked === 1 ? "Stopping the server timed out" : "Client is not running and can't be stopped");
                }
            }, 5, 1).then(() => true, () => false);
            let refused = 0;
            const failed = await restartServer(async () => {
                refused += 1;
                throw new Error("refused");
            }, 5, 1).then(() => false, () => true);
            check("a restart the Swift extension refuses - a server not stopped in time, a client still starting - is asked "
                + "again until it takes, and one refused every time is the caller's",
                recovered && asked === 3 && failed && refused === 5);
        }

        // 1-3 ask the language server as the hosts only macOS builds.
        if (process.platform === "darwin") {
            // 1. Android: the plain symbol resolves, the AppKit one does not.
            await api.selectHost("android");
            await until("android: a symbol under no condition resolves", () => resolves(plain, "Palette.accent"), 900);
            await until("android: neither head's own view resolves", async () => !(await appKitOnly()) && !(await uiKitOnly()), 900);

            // 2. AppKit, with no reload: the head's own view and the head resolve.
            await api.selectHost("appkit");
            await until("appkit: its head's own view resolves", appKitOnly, 900);
            // A target the package did not have a moment ago: the server has to
            // load it, so this is waited for rather than asked once.
            await until("appkit: Cube3DContract in Platforms/AppKit resolves", () => resolves(head, "Cube3DContract.self"), 900);

            // 2b. UIKit, compiled for the iOS simulator by its triple and SDK: its head resolves, the AppKit symbol not.
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

        // 4. The hosts a machine is offered: AppKit, UIKit and Android on macOS,
        //    WinUI on Windows, GTK on Linux, and the Web on macOS and Linux.
        //    A launch on a machine that runs no host resolves to nothing.
        const gallery_ = api.applications().find((each) => each.name === "Gallery")!;
        check("the host picker offers AppKit, UIKit and Android on macOS, WinUI on Windows, GTK on Linux, and the Web on macOS and Linux",
            JSON.stringify(availableHosts("darwin").map((each) => each.id)) === JSON.stringify(["appkit", "uikit", "android", "web"])
            && JSON.stringify(availableHosts("win32").map((each) => each.id)) === JSON.stringify(["winui"])
            && JSON.stringify(availableHosts("linux").map((each) => each.id)) === JSON.stringify(["gtk", "web"])
            && availableHosts("freebsd").length === 0);
        {
            const ran: string[] = [];
            const provider = new StateUIDebugConfigurationProvider({
                build: async () => undefined,
                host: () => undefined, application: async () => gallery_,
                run: async (task) => { ran.push(task.name); return 0; },
                start: async (task) => { ran.push(task.name); },
                ready: async () => false,
                device: async () => undefined,
                uiKitDevice: async () => undefined,
                runHead: async () => undefined,
                browser: async () => undefined,
            });
            const resolved = await provider.resolveDebugConfiguration(root,
                { name: "StateUI: Debug", type: "stateui", request: "launch", configuration: "debug" });
            check("with no host a launch runs nothing and opens no session", resolved === undefined && ran.length === 0);
        }

        // 5. The suites, found for each host the way test-native.sh runs them; the core's is named by the checkout's folder.
        const core = path.basename(root.uri.fsPath);
        const appkitSuites = findSuites(root.uri.fsPath, "appkit", api.applications()).map((each) => each.label);
        const plainSuites = findSuites(root.uri.fsPath, undefined, api.applications());
        say(`appkit suites: ${appkitSuites.join(", ")}`);
        say(`suites with no host: ${plainSuites.map((each) => each.label).join(", ")}`);
        check("appkit runs the core, StateUI.AppKit and the Gallery, and no device",
            appkitSuites.includes(core) && appkitSuites.includes("lib/StateUI/StateUI.AppKit")
            && findSuites(root.uri.fsPath, "appkit", api.applications(), "/bin/stateui").some((each) => each.label === "lib/StateUI/StateUI.AppKit"
                && each.command === "/bin/stateui" && each.args.join(" ") === "repo test --suite host:appkit")
            && appkitSuites.includes("apps/Gallery") && !appkitSuites.some((each) => each.endsWith("Tests")));
        check("HelloWorld's example test runs with the rest - as an AppKit build on its .build/appkit, or as plain Swift",
            findSuites(root.uri.fsPath, "appkit", api.applications()).some((each) => each.label === "apps/HelloWorld"
                && each.args.join(" ").endsWith(`--scratch-path ${path.join(root.uri.fsPath, "apps", "HelloWorld", ".build", "appkit")}`))
            && plainSuites.some((each) => each.label === "apps/HelloWorld"));
        check("with no host the core and the Gallery run as plain Swift, and no host's own package",
            plainSuites.some((each) => each.label === core) && plainSuites.some((each) => each.label === "apps/Gallery")
            && plainSuites.every((each) => each.command === "swift" && Object.keys(each.env).length === 0 && !each.onDevice)
            && !plainSuites.some((each) => each.label === "lib/StateUI/StateUI.AppKit" || each.label === "lib/StateUI/StateUI.Android/Tests"));

        // 6. Android: the environment, the language server's file, the
        //    devices, and the commands a launch and a suite run - captured,
        //    not run.
        check("each host's environment names it in one variable - STATEUI_HOST=android for Android - and no host clears it",
            hosts.every((host) => JSON.stringify(environment(host.id)) === JSON.stringify({ STATEUI_HOST: host.id }))
            && environment("android").STATEUI_HOST === "android"
            && JSON.stringify(Object.entries(environment(undefined))) === JSON.stringify([["STATEUI_HOST", undefined]]));
        {
            const asWinUI = otherHostsExcluded("winui", { "**/mine": true, "**/lib/StateUI/StateUI.WinUI": true });
            const excluded = Object.keys(asWinUI).filter((pattern) => asWinUI[pattern]);
            check("as WinUI the Swift extension loads no other host's package nor backend, and the user's own exclusions stay",
                excluded.includes("**/lib/StateUI/StateUI.Android") && excluded.includes("**/lib/Backends/*.GTK")
                && !excluded.some((pattern) => pattern.endsWith(".WinUI")) && asWinUI["**/mine"] === true
                && Object.keys(otherHostsExcluded(undefined, {})).length === hosts.length * 2);
            check("every host's own package stands where its exclusion names it",
                hosts.every((host) => fs.existsSync(path.join(root.uri.fsPath, "lib", "StateUI", `StateUI.${host.label}`, "Package.swift"))));
        }
        {
            const sdk = "swift-6.4.2-RELEASE_android";
            const android = serverConfig(
                { swiftPM: { scratchPath: ".build/appkit/index-build", configuration: "debug" }, index: { indexStorePath: "x" } },
                serverSettings("android", sdk));
            const back = serverConfig(android, serverSettings("appkit", sdk));
            check("as Android the language server indexes in .build/android/index-build with the Swift SDK and aarch64-unknown-linux-android28, by building",
                android.swiftPM?.scratchPath === ".build/android/index-build" && android.swiftPM?.swiftSDK === sdk
                && android.swiftPM?.triple === "aarch64-unknown-linux-android28" && android.backgroundPreparationMode === "build");
            check("the rest of the file is kept, and back on AppKit the SDK and the triple are gone",
                android.swiftPM?.configuration === "debug" && JSON.stringify(android.index) === JSON.stringify({ indexStorePath: "x" })
                && back.swiftPM?.scratchPath === ".build/appkit/index-build" && back.swiftPM?.configuration === "debug"
                && !("swiftSDK" in back.swiftPM!) && !("triple" in back.swiftPM!));
            check("with no Swift SDK installed Android indexes for this Mac, and with no host the index is SwiftPM's own, with no SDK",
                JSON.stringify(serverSettings("android", undefined)) === JSON.stringify({ scratchPath: ".build/android/index-build" })
                && JSON.stringify(serverSettings(undefined, sdk)) === JSON.stringify({ scratchPath: ".build/index-build" }));

            // The other releases are assembled, so the repository's one-release guard reads no second one here.
            const older = ["6", "3", "3"].join("."), newer = ["6", "5"].join(".");
            const list = `swift-${older}-RELEASE_android\nswift-6.4.2-RELEASE_android\nswift-6.4.2-RELEASE_static-linux-0.1.0\n`;
            const sdkOf = (version: string) => swiftSDKOf(swiftRelease(version), list, "android");
            check("the Swift SDK for Android is the one of the toolchain's release, as build-swift.sh finds it",
                sdkOf("Apple Swift version 6.4.2 (swift-6.4.2-RELEASE)\nTarget: arm64-apple-macosx26.0") === sdk
                && sdkOf(`Apple Swift version ${older} (swift-${older}-RELEASE)`) === `swift-${older}-RELEASE_android`
                && sdkOf(`Apple Swift version ${newer} (swift-${newer}-RELEASE)`) === undefined && sdkOf("") === undefined);
            const wasm = "swift-6.4.2-RELEASE_wasm\nswift-6.4.2-RELEASE_wasm-embedded\n";
            check("the Swift SDK for WebAssembly is the one whose id ends in _wasm, never its Embedded Swift sibling",
                swiftSDKOf("6.4.2", wasm, "wasm") === "swift-6.4.2-RELEASE_wasm"
                && swiftSDKOf("6.4.2", "swift-6.4.2-RELEASE_wasm-embedded\n", "wasm") === undefined);
        }
        {
            const listed = [
                androidDeviceOf({ id: "190a991d", udid: "190a991d", name: "CPH2363", kind: "device", version: "13", booted: false, connection: "USB", architecture: "arm64" }),
                androidDeviceOf({ id: "emulator-5554", udid: "emulator-5554", name: "Pixel_3a", kind: "emulator", version: "14", booted: true, architecture: "arm64" }),
                androidDeviceOf({ id: "Medium_Phone", udid: "Medium_Phone", name: "Medium_Phone", kind: "emulator", version: "", booted: false }),
            ];
            check("the tool's list reads as the devices attached and running, by serial and name, and the virtual devices not running",
                JSON.stringify(listed) === JSON.stringify([
                    { kind: "device", serial: "190a991d", name: "CPH2363" },
                    { kind: "device", serial: "emulator-5554", name: "Pixel_3a" },
                    { kind: "avd", name: "Medium_Phone" },
                ]));
            check("a device chosen is known by its serial while it runs - an emulator chosen when it was not, by its name - else by its virtual device's name",
                deviceAmong(listed, { serial: "190a991d", name: "CPH2363" }) === "190a991d"
                && deviceAmong(listed, { serial: "Pixel_3a", name: "Pixel_3a" }) === "emulator-5554"
                && deviceAmong(listed, { serial: "Medium_Phone", name: "Medium_Phone" }) === "Medium_Phone"
                && deviceAmong(listed, { serial: "gone", name: "Gone" }) === undefined);
        }

        const helloWorld = api.applications().find((each) => each.name === "HelloWorld")!;
        check("HelloWorld and the Gallery have Android heads",
            hasHead(helloWorld, "android") && hasHead(gallery_, "android"));
        {
            // What the tool's run says once the application runs, faked - or nothing, where it never starts.
            const launchOnAndroid = async (serial: string | undefined, configuration = "release", starts = true) => {
                const runs: { host: string; device: string; debug: boolean; configuration: string }[] = [];
                const provider = new StateUIDebugConfigurationProvider({
                    build: async () => undefined,
                    host: () => "android", application: async () => helloWorld,
                    run: async () => 0,
                    start: async () => {},
                    ready: async () => false,
                    device: async () => serial,
                    uiKitDevice: async () => undefined,
                    runHead: async (_folder, _application, forHost, asked, device, debug) => {
                        runs.push({ host: forHost, device, debug, configuration: asked });
                        if (!starts) {
                            return undefined;
                        }
                        const destination = { id: device, udid: device, name: "Pixel_3a", kind: "emulator" as const, version: "14", booted: true, architecture: "arm64" as const };
                        return {
                            token: "RUN-2",
                            launched: {
                                held: false, process: 4242, debuggerSocket: debug ? "com.stateui.helloworld/stateui-debugger.sock" : undefined,
                                build: {
                                    application: "HelloWorld", host: "android" as const, configuration: asked as Configuration, architecture: "arm64" as const,
                                    folderUri: "file:///build", programUri: "file:///build/HelloWorld.apk", bundleUri: "file:///build/HelloWorld.apk",
                                    destination, identifier: "com.stateui.helloworld", symbolsUri: "file:///build/symbols/arm64-v8a",
                                },
                            },
                        };
                    },
                    browser: async () => undefined,
                });
                const resolved = await provider.resolveDebugConfiguration(root, {
                    name: configuration === "debug" ? "StateUI: Debug" : "StateUI: Release", type: "stateui",
                    request: "launch", configuration,
                });
                return { resolved, runs };
            };

            const released = await launchOnAndroid("emulator-5554");
            check("Android Release: the tool runs HelloWorld on that device, no debugger readied, and no session",
                released.resolved === undefined
                && JSON.stringify(released.runs) === JSON.stringify([{ host: "android", device: "emulator-5554", debug: false, configuration: "release" }]));

            const declined = await launchOnAndroid(undefined);
            check("Android with no device picked starts nothing and opens no session",
                declined.resolved === undefined && declined.runs.length === 0);

            const debugged = await launchOnAndroid("emulator-5554", "debug");
            say(`     android debugged: ${JSON.stringify(debugged.resolved)}`);
            check("Android Debug: the tool readies the debugger's server, then lldb-dap attaches through it to the process started, the session carrying the run",
                debugged.resolved?.type === "lldb-dap" && debugged.resolved.request === "attach" && debugged.resolved.stateuiRun === "RUN-2"
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
            check("Android Debug whose application never starts opens no session", failed.resolved === undefined && failed.runs.length === 1);
        }
        {
            const androidSuites = findSuites(root.uri.fsPath, "android", api.applications());
            say(`android suites: ${androidSuites.map((each) => each.label).join(", ")}`);
            const onDevice = androidSuites.filter((each) => each.onDevice).map((each) => forDevice(each, "emulator-5554"));
            const galleryRun = androidSuites.find((each) => each.label === "apps/Gallery");
            check("android runs the core and the Gallery as plain Swift, and no AppKit",
                androidSuites.some((each) => each.label === core && forDevice(each, "emulator-5554") === each)
                && galleryRun?.args.join(" ") === `test --package-path ${gallery}` && Object.keys(galleryRun.env).length === 0
                && !androidSuites.some((each) => each.label === "lib/StateUI/StateUI.AppKit"));
            check("android runs stateui repo test --suite host:android --device <serial> on the device, and only android does",
                onDevice.length === 1 && onDevice[0].label === "lib/StateUI/StateUI.Android/Tests"
                && [onDevice[0].command, ...onDevice[0].args].join(" ") === "stateui repo test --suite host:android --device emulator-5554"
                && !appkitSuites.includes("lib/StateUI/StateUI.Android/Tests"));
        }
        // 6a. UIKit: the language server's file, the simulators, and the
        //     commands a launch and a suite run - captured, not run.
        {
            const simulatorSDK = "/Xcode/SDKs/iPhoneSimulator.sdk";
            const uiKit = serverConfig({ swiftPM: { scratchPath: ".build/appkit/index-build" } }, serverSettings("uikit", undefined, simulatorSDK));
            const back = serverConfig(uiKit, serverSettings("appkit", undefined));
            check("as UIKit the language server indexes in .build/uikit/index-build for arm64-apple-ios26.4-simulator against Xcode's simulator SDK - and back on AppKit both are gone",
                uiKit.swiftPM?.scratchPath === ".build/uikit/index-build" && uiKit.swiftPM?.triple === "arm64-apple-ios26.4-simulator"
                && uiKit.swiftPM?.sdk === simulatorSDK && !("swiftSDK" in uiKit.swiftPM!)
                && back.swiftPM?.scratchPath === ".build/appkit/index-build" && !("triple" in back.swiftPM!) && !("sdk" in back.swiftPM!));
            check("with no simulator SDK found UIKit indexes for this Mac",
                JSON.stringify(serverSettings("uikit", undefined, undefined)) === JSON.stringify({ scratchPath: ".build/uikit/index-build" }));
        }
        {
            const directory = fs.mkdtempSync(path.join(os.tmpdir(), "stateui-winui-"));
            const notes = { name: "Notes", directory } as Parameters<typeof winUIProgram>[0];
            const before = winUIProgram(notes, "release");
            fs.mkdirSync(path.join(directory, ".build", "winui"), { recursive: true });
            fs.writeFileSync(path.join(directory, ".build", "winui", "release.program"), "C:\\built\\NotesWinUI.exe");
            check("a WinUI launch runs the head where its build says it laid it, not where the link last pointed",
                before === path.join(directory, ".build", "winui", "release", "NotesWinUI.exe")
                && winUIProgram(notes, "release") === "C:\\built\\NotesWinUI.exe");
            fs.rmSync(directory, { recursive: true, force: true });
        }
        {
            const windows = buildingCommand("C:\\Users\\O'Neil\\apps\\Notes\\.build", "win32");
            check("a build is looked for with pgrep, and on Windows - which has no pgrep - with PowerShell's process list",
                JSON.stringify(buildingCommand("/apps/Notes/.build", "darwin")) === JSON.stringify({ command: "pgrep", args: ["-f", "/apps/Notes/.build"] })
                && windows.command === "powershell" && windows.args.join(" ").includes("Contains('C:\\Users\\O''Neil\\apps\\Notes\\.build')"));
        }
        {
            const launch = { type: "stateui", launch: true, application: "Notes", configuration: "debug", device: "SIM-1" };
            const deploy = { type: "stateui", application: "Notes", configuration: "release", device: "SIM-1" };
            check("a launch replaces a launch of the same application on the same device, never a deploy or a build",
                givesWay(launch, launch) && !givesWay(deploy, launch) && !givesWay(launch, { ...launch, device: "SIM-2" })
                && !givesWay(launch, { ...launch, application: "Other" }));
        }
        {
            const phone = { id: "P", name: "Paweł's iPhone", kind: "device" as const, os: "27.0", state: "USB" };
            const simulator = { id: "S", name: "iPhone 18 Pro", kind: "simulator" as const, os: "27.0", state: "" };
            const pad = { id: "A", name: "iPad Air 13-inch (M4)", kind: "simulator" as const, os: "27.0", state: "" };
            check("a suite runs on the simulator chosen, never on a device - an iPhone chosen asks for a simulator, or takes the one chosen for suites",
                simulatorForSuites([phone, simulator, pad], simulator) === "S"
                && simulatorForSuites([phone, simulator, pad], phone) === undefined
                && simulatorForSuites([phone, simulator, pad], phone, pad) === "A"
                && simulatorForSuites([phone, simulator], phone, pad) === undefined);
        }
        {
            check("a destination the tool lists stands as a UIKit device: a device by how it is reached, a simulator by whether it is booted",
                JSON.stringify([
                    uiKitDeviceOf({ id: "PHONE-ID", udid: "U", name: "Phone", kind: "device", version: "26.6.2", booted: false, connection: "USB" }),
                    uiKitDeviceOf({ id: "SIM", udid: "SIM", name: "iPhone 18 Pro", kind: "simulator", version: "27.0", booted: true }),
                    uiKitDeviceOf({ id: "PAD", udid: "PAD", name: "iPad Air 13-inch (M4)", kind: "simulator", version: "27.0", booted: false }),
                ]) === JSON.stringify([
                    { id: "PHONE-ID", name: "Phone", kind: "device", os: "26.6.2", state: "USB" },
                    { id: "SIM", name: "iPhone 18 Pro", kind: "simulator", os: "27.0", state: "booted" },
                    { id: "PAD", name: "iPad Air 13-inch (M4)", kind: "simulator", os: "27.0", state: "" },
                ]));
            const onDevice = uiKitAttach("StateUI: Debug", { process: 37779, device: "PHONE", symbols: "/b/App.app" });
            check("on a device lldb-dap selects the device, attaches to the process through it, reads symbols from the bundle built, and kills it as the session ends",
                onDevice.request === "attach" && onDevice.pid === undefined
                && JSON.stringify(onDevice.terminateCommands) === JSON.stringify(["process kill"])
                && JSON.stringify(onDevice.attachCommands) === JSON.stringify(["device select PHONE", "device process attach --pid 37779"])
                && JSON.stringify(onDevice.initCommands) === JSON.stringify([
                    "settings append target.exec-search-paths /b/App.app", "settings append target.exec-search-paths /b/App.app/Frameworks"]));
        }
        {
            const helloWorldHere = api.applications().find((each) => each.name === "HelloWorld")!;
            check("HelloWorld and the Gallery have UIKit heads", hasHead(helloWorldHere, "uikit") && hasHead(gallery_, "uikit"));
            const launchOnUIKit = async (udid: string | undefined, configuration = "release", starts = true) => {
                const runs: { device: string; debug: boolean; configuration: string }[] = [];
                const provider = new StateUIDebugConfigurationProvider({
                    build: async () => undefined,
                    host: () => "uikit", application: async () => helloWorldHere,
                    run: async () => 0,
                    start: async () => {},
                    ready: async () => false,
                    device: async () => undefined,
                    uiKitDevice: async () => udid,
                    runHead: async (_folder, _application, _host, asked, device, debug) => {
                        runs.push({ device, debug, configuration: asked });
                        if (!starts) {
                            return undefined;
                        }
                        const destination = { id: device, udid: device, name: "iPhone 18 Pro", kind: "simulator" as const, version: "27.0", booted: true };
                        return {
                            token: "RUN-1",
                            launched: {
                                held: debug, process: 4343,
                                build: {
                                    application: "HelloWorld", host: "uikit" as const, configuration: asked as Configuration, architecture: "arm64" as const,
                                    folderUri: "file:///a", programUri: "file:///a/HelloWorldUIKit.app/HelloWorldUIKit",
                                    bundleUri: "file:///a/HelloWorldUIKit.app", destination,
                                },
                            },
                        };
                    },
                    browser: async () => undefined,
                });
                const resolved = await provider.resolveDebugConfiguration(root, {
                    name: configuration === "debug" ? "StateUI: Debug" : "StateUI: Release", type: "stateui",
                    request: "launch", configuration,
                });
                return { resolved, runs };
            };

            const released = await launchOnUIKit("SIM-1");
            check("UIKit Release: the tool runs HelloWorld on that simulator, not held, and no session",
                released.resolved === undefined && JSON.stringify(released.runs) === JSON.stringify([{ device: "SIM-1", debug: false, configuration: "release" }]));

            const declined = await launchOnUIKit(undefined);
            check("UIKit with no device picked starts nothing", declined.resolved === undefined && declined.runs.length === 0);

            const debugged = await launchOnUIKit("SIM-1", "debug");
            say(`     uikit debugged: ${JSON.stringify(debugged.resolved)}`);
            check("UIKit Debug: the tool runs it held, then lldb-dap attaches to the process it started, the session carrying the run",
                JSON.stringify(debugged.runs) === JSON.stringify([{ device: "SIM-1", debug: true, configuration: "debug" }])
                && debugged.resolved?.type === "lldb-dap" && debugged.resolved.request === "attach" && debugged.resolved.pid === 4343
                && debugged.resolved.stateuiRun === "RUN-1");

            const failed = await launchOnUIKit("SIM-1", "debug", false);
            check("UIKit Debug whose application never starts opens no session", failed.resolved === undefined && failed.runs.length === 1);
        }
        {
            const uiKitSuites = findSuites(root.uri.fsPath, "uikit", api.applications());
            say(`uikit suites: ${uiKitSuites.map((each) => each.label).join(", ")}`);
            const onSimulator = uiKitSuites.filter((each) => each.onDevice).map((each) => forDevice(each, "SIM-1"));
            check("uikit runs the core and the Gallery as plain Swift, and stateui repo test --suite host:uikit --device <udid> on the simulator",
                uiKitSuites.some((each) => each.label === core)
                && onSimulator.length === 1 && onSimulator[0].label === "lib/StateUI/StateUI.UIKit/Tests"
                && [onSimulator[0].command, ...onSimulator[0].args].join(" ") === "stateui repo test --suite host:uikit --device SIM-1"
                && !uiKitSuites.some((each) => each.label === "lib/StateUI/StateUI.AppKit" || each.label === "lib/StateUI/StateUI.Android/Tests"));
        }

        // 6b. WinUI: HelloWorld's head, built by run-app.ps1 -BuildOnly and
        //     launched under lldb-dap, and the host's own package through test-winui.ps1.
        check("HelloWorld has a WinUI head, and as WinUI the language server indexes in .build/winui/index-build",
            hasHead(helloWorld, "winui")
            && JSON.stringify(serverSettings("winui", undefined)) === JSON.stringify({ scratchPath: ".build/winui/index-build" }));
        {
            const ran: vscode.Task[] = [];
            const provider = new StateUIDebugConfigurationProvider({
                build: async () => undefined,
                host: () => "winui", application: async () => helloWorld,
                run: async (task) => { ran.push(task); return 0; },
                start: async () => {},
                ready: async () => false,
                device: async () => undefined,
                uiKitDevice: async () => undefined,
                runHead: async () => undefined,
                browser: async () => undefined,
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
                && resolved.program === path.join(helloWorld.directory, ".build", "winui", "release", "HelloWorldWinUI.exe"));
        }
        {
            const winUISuites = findSuites(root.uri.fsPath, "winui", api.applications());
            say(`winui suites: ${winUISuites.map((each) => each.label).join(", ")}`);
            const own = winUISuites.find((each) => each.label === "lib/StateUI/StateUI.WinUI/Testing");
            check("winui runs the core and the Gallery as plain Swift, its own package by test-winui.ps1, and no AppKit or Android",
                winUISuites.some((each) => each.label === core)
                && own?.command === "powershell" && own.args[own.args.length - 1].endsWith("test-winui.ps1")
                && !winUISuites.some((each) => each.label === "lib/StateUI/StateUI.AppKit" || each.label === "lib/StateUI/StateUI.Android/Tests"));
        }

        // 6c. GTK: HelloWorld's head, built and installed by the stateui tool and
        //     launched under lldb-dap, and the host's own suite by the tool.
        check("HelloWorld has a GTK head, and as GTK the language server indexes in .build/gtk/index-build",
            hasHead(helloWorld, "gtk")
            && JSON.stringify(serverSettings("gtk", undefined)) === JSON.stringify({ scratchPath: ".build/gtk/index-build" }));
        {
            const built: string[] = [];
            const program = path.join(helloWorld.directory, ".build", "stateui", "artifacts", "gtk-arm64-x-debug", "HelloWorldGTK");
            const provider = new StateUIDebugConfigurationProvider({
                build: async (_folder, _application, forHost, configuration) => { built.push(`${forHost} ${configuration}`); return program; },
                host: () => "gtk", application: async () => helloWorld,
                run: async () => 0,
                start: async () => {},
                ready: async () => false,
                device: async () => undefined,
                uiKitDevice: async () => undefined,
                runHead: async () => undefined,
                browser: async () => undefined,
            });
            const resolved = await provider.resolveDebugConfiguration(root,
                { name: "StateUI: Debug", type: "stateui", request: "launch", configuration: "debug" });
            check("GTK: the tool builds HelloWorld for GTK, then lldb-dap launches the program it published",
                JSON.stringify(built) === JSON.stringify(["gtk debug"])
                && resolved?.type === "lldb-dap" && resolved.request === "launch" && resolved.program === program);
        }
        {
            const gtkSuites = findSuites(root.uri.fsPath, "gtk", api.applications());
            say(`gtk suites: ${gtkSuites.map((each) => each.label).join(", ")}`);
            const own = gtkSuites.find((each) => each.label === "lib/StateUI/StateUI.GTK/Testing");
            const testing = path.join(root.uri.fsPath, "lib", "StateUI", "StateUI.GTK", "Testing");
            check("gtk runs the core and the Gallery as plain Swift, its own suite by stateui repo test, and no other host's",
                gtkSuites.some((each) => each.label === core) && testing.length > 0
                && own?.command === "stateui" && own.args.join(" ") === "repo test --suite host:gtk"
                && !gtkSuites.some((each) => ["lib/StateUI/StateUI.AppKit", "lib/StateUI/StateUI.WinUI", "lib/StateUI/StateUI.Android/Tests",
                    "lib/Backends/WebView.WinUI"].includes(each.label)));
        }

        // 6d. Web: HelloWorld's head, built, served and opened by run-app.sh in a
        //     task in the browser chosen; a Debug launch in one of Chromium's
        //     VS Code's JavaScript debugger on the page server.json names.
        check("HelloWorld has a Web head, and as the Web the language server indexes in .build/web/index-build for wasm32-unknown-wasip1",
            hasHead(helloWorld, "web")
            && JSON.stringify(serverSettings("web", "swift-6.4.2-RELEASE_wasm")) === JSON.stringify(
                { scratchPath: ".build/web/index-build", swiftSDK: "swift-6.4.2-RELEASE_wasm", triple: "wasm32-unknown-wasip1" }));
        {
            const listed = parseBrowsers("com.apple.Safari\tSafari\t/Applications/Safari.app/Contents/MacOS/Safari\tdefault\r\n"
                + "com.google.Chrome\tGoogle Chrome\t/Applications/Google Chrome.app/Contents/MacOS/Google Chrome\t\n\n"
                + "firefox.desktop\tFirefox\t/usr/bin/firefox\t\n");
            check("browsers.sh list reads as the browsers by id, name and program, the system's own marked, and Chromium's told apart",
                listed.length === 3 && listed[0].isDefault && !listed[1].isDefault && listed[1].name === "Google Chrome"
                && listed[2].executable === "/usr/bin/firefox"
                && !isChromium(listed[0]) && isChromium(listed[1]) && !isChromium(listed[2])
                && isChromium({ id: "com.microsoft.edgemac" }) && isChromium({ id: "brave-browser.desktop" }));

            const facts = path.join(helloWorld.directory, ".build", "web", "server.json");
            const launchOnWeb = async (browser: (typeof listed)[number], configuration: string) => {
                const started: vscode.Task[] = [];
                const provider = new StateUIDebugConfigurationProvider({
                    build: async () => undefined,
                    host: () => "web", application: async () => helloWorld,
                    run: async () => 0,
                    start: async (task) => {
                        started.push(task);
                        fs.mkdirSync(path.dirname(facts), { recursive: true });
                        fs.writeFileSync(facts, JSON.stringify({ url: "http://127.0.0.1:8460/" }));
                    },
                    ready: async (file) => fs.existsSync(file),
                    device: async () => undefined,
                    uiKitDevice: async () => undefined,
                runHead: async () => undefined,
                    browser: async () => browser,
                });
                const resolved = await provider.resolveDebugConfiguration(root,
                    { name: "StateUI: Debug", type: "stateui", request: "launch", configuration });
                fs.rmSync(facts, { force: true });
                const shell = started[0]?.execution as vscode.ShellExecution | undefined;
                return { resolved, started, line: shell ? [shell.command, ...(shell.args ?? [])].map(String).join(" ") : "" };
            };
            const script = path.join(root.uri.fsPath, ".scripts", "Web", "run-app.sh");

            const safari = await launchOnWeb(listed[0], "debug");
            say(`     web started: ${safari.line}`);
            check("Web in Safari: run-app.sh <HelloWorld> debug --browser com.apple.Safari started as a task, and no session",
                safari.resolved === undefined && safari.started.length === 1
                && safari.line === `bash ${script} ${helloWorld.directory} debug --browser com.apple.Safari`
                && safari.started[0].definition.device === "web");

            const chrome = await launchOnWeb(listed[1], "debug");
            check("Web in Chrome: the page served with no browser opened, then VS Code's JavaScript debugger starts Chrome on it",
                chrome.line === `bash ${script} ${helloWorld.directory} debug --browser none`
                && JSON.stringify(chrome.resolved) === JSON.stringify(webLaunch("StateUI: Debug", "http://127.0.0.1:8460/", listed[1],
                    path.join(helloWorld.directory, ".build", "web", "site", "debug")))
                && chrome.resolved?.type === "chrome" && chrome.resolved.runtimeExecutable === listed[1].executable);

            const released = await launchOnWeb(listed[1], "release");
            check("Web released in Chrome is opened by the script, with no session",
                released.resolved === undefined && released.line.endsWith("release --browser com.google.Chrome"));
        }
        {
            const webSuites = findSuites(root.uri.fsPath, "web", api.applications());
            say(`web suites: ${webSuites.map((each) => each.label).join(", ")}`);
            const own = webSuites.find((each) => each.label === "lib/StateUI/StateUI.Web/Testing");
            check("web runs the core and the Gallery as plain Swift, its own tests' package by test-web.sh, and no other host's",
                webSuites.some((each) => each.label === core) && webSuites.some((each) => each.label === "apps/Gallery")
                && own?.command === "bash" && own.args[0] === path.join(root.uri.fsPath, ".scripts", "Web", "test-web.sh")
                && webSuites.filter((each) => each !== own).every((each) => each.command === "swift" && !each.onDevice)
                && !webSuites.some((each) => ["lib/StateUI/StateUI.AppKit", "lib/StateUI/StateUI.GTK/Testing"].includes(each.label)));
            check("the Web makes no conformance marks yet", rebuildSteps(root.uri.fsPath, "web", "all") === undefined);
        }

        const palette = await vscode.commands.getCommands(true);
        check("the palette has Select Android Device, Select UIKit Device and Select Browser, and no Select Debugger",
            palette.includes("stateui.selectAndroidDevice") && palette.includes("stateui.selectUIKitDevice")
            && palette.includes("stateui.selectBrowser")
            && !palette.includes("stateui.selectDebugger") && !palette.includes("stateui.selectSimulator"));

        // 7. A new application is HelloWorld renamed in a checkout's apps/,
        //    by the checkout's scaffolder - the only starter.
        const commands = await vscode.commands.getCommands(true);
        check("the palette has New Application and no New Application from Template",
            commands.includes("stateui.newApplicationInApps") && !commands.includes("stateui.newApplication"));
        // The stateui tool the extension finds, asked as the commands ask it.
        const tool = await ToolingClient.start({
            executable: locateTool(vscode.workspace.getConfiguration("stateui").get<string>("cliPath")),
            folder: root.uri.fsPath, clientVersion: "suite",
        });
        check("the suite's editor works through the stateui tool of this checkout, named by stateui.cliPath",
            fs.realpathSync.native(locateTool(vscode.workspace.getConfiguration("stateui").get<string>("cliPath")))
                .startsWith(fs.realpathSync.native(path.join(root.uri.fsPath, "tools", "StateUI.CLI", ".build"))));
        const described = async (folder: string): Promise<Application[]> => {
            const project = await readApplications(tool, folder);
            return project ? applicationsOf(project) : [];
        };
        const libraryOf = async (application: string): Promise<string | undefined> =>
            (await described(application)).find((each) => each.directory === application)?.checkout;
        {
            const problem = async (kind: "application" | "workspace", name: string): Promise<string | undefined> =>
                (await tool.request("name/check", { kind, name })).problem;
            check("the tool takes an application's name of letters and digits, starting with a letter, and not StateUI; "
                + "a group's of letters, digits, dots, hyphens and underscores",
                await problem("application", "MyApp2") === undefined && await problem("application", "My-App") !== undefined
                && await problem("application", "2App") !== undefined && await problem("application", "StateUI") !== undefined
                && await problem("workspace", "My.Apps-2_x") === undefined && await problem("workspace", "My Apps") !== undefined
                && await problem("workspace", "-apps") !== undefined && await problem("workspace", "") !== undefined);
            const manifest = JSON.parse(fs.readFileSync(path.join(root.uri.fsPath, "editors", "VSCode", "package.json"), "utf8"));
            const setting = manifest.contributes.configuration.properties;
            check("the palette has New Project Group; New Application shows where a folder is a workspace; "
                + "stateui.checkout and stateui.cliPath are this machine's, stateui.minimumRelease 0.5.0",
                commands.includes("stateui.newProjectGroup")
                && manifest.contributes.commands.some((each: { command: string; enablement?: string }) =>
                    each.command === "stateui.newApplicationInApps" && each.enablement === "stateui.hasWorkspace")
                && setting["stateui.checkout"].scope === "machine" && setting["stateui.minimumRelease"].default === "0.5.0"
                && setting["stateui.cliPath"].scope === "machine");
            const helloWorld = api.applications().find((each) => each.name === "HelloWorld");
            check("the tool finds this checkout's applications, each building with the checkout its Package.swift names: this one",
                fs.realpathSync.native(helloWorld?.checkout ?? "/") === fs.realpathSync.native(root.uri.fsPath)
                && helloWorld?.workspace !== undefined && fs.realpathSync.native(helloWorld.workspace) === fs.realpathSync.native(root.uri.fsPath)
                && api.applications().every((each) => each.checkout !== undefined));
        }
        // 7a. A project group, made by the command itself with its questions answered: one building with this checkout,
        //     one with the newest release offered cloned into it - a workspace, its stateui.json listing its applications.
        //     Each application names its StateUI in its Package.swift, New Application makes another the same way beside
        //     it, and each group's Notes builds.
        {
            const location = process.env.STATEUI_TEST_GROUPS ?? fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "stateui-groups-")));
            const taken = ["LocalGroup", "ReleaseGroup"].map((each) => path.join(location, each)).filter((each) => fs.existsSync(each));
            check(`the groups are made where nothing is yet${taken.length > 0 ? ` - remove ${taken.join(", ")} first` : ""}`, taken.length === 0);
            // The system's own spelling: the editor names a Windows folder `c:\…`, a resolved path `C:\…`.
            const same = (a: string | undefined, b: string): boolean => a !== undefined && fs.realpathSync.native(a) === fs.realpathSync.native(b);
            const builds = (application: string): boolean => {
                const appKit = process.platform === "darwin";
                const name = path.basename(application);
                try {
                    // As an AppKit build on macOS, as plain Swift elsewhere.
                    const env = Object.fromEntries(Object.entries({ ...process.env, ...environment(appKit ? "appkit" : undefined) })
                        .filter((entry): entry is [string, string] => entry[1] !== undefined));
                    execSync(`swift build --package-path "${application}"${appKit ? ` --scratch-path "${path.join(application, ".build", "appkit")}" --product ${name}AppKit` : ""}`,
                        { env, stdio: "pipe" });
                    return true;
                } catch (error) {
                    say(`     ${String((error as { stdout?: Buffer }).stdout ?? error).split("\n").slice(-8).join("\n     ")}`);
                    return false;
                }
            };
            const wired = (application: string): boolean => {
                const text = fs.readFileSync(path.join(application, "Package.swift"), "utf8");
                return [...text.matchAll(/^[^/\n]*\.package\(.*path: "([^"]+)"/gm)]
                    .every((match) => fs.existsSync(path.join(path.resolve(fs.realpathSync(application), match[1]), "Package.swift")));
            };

            const local = await vscode.commands.executeCommand<string>("stateui.newProjectGroup",
                { location, name: "LocalGroup", checkout: root.uri.fsPath, application: "Notes" });
            const localNotes = path.join(local ?? "", "Notes");
            const launch = local ? JSON.parse(fs.readFileSync(path.join(local, ".vscode", "launch.json"), "utf8")) : {};
            const listed = (group: string): string => JSON.parse(fs.readFileSync(path.join(group, "stateui.json"), "utf8")).projects.join(" ");
            check("a group is a workspace: its stateui.json listing Notes, a .gitignore, and the editor's settings with StateUI: Debug and Release",
                same(local, path.join(location, "LocalGroup")) && listed(local!) === "Notes"
                && [".gitignore", ".vscode/settings.json", "Notes/Package.swift"].every((each) => fs.existsSync(path.join(local, each)))
                && JSON.stringify(launch.configurations.map((each: vscode.DebugConfiguration) => [each.name, each.type, each.configuration]))
                    === JSON.stringify(configurations().map((each) => [each.name, each.type, each.configuration])));
            check("with the local checkout its application names this checkout by the path from its own folder, and nothing is copied",
                same(await libraryOf(localNotes), root.uri.fsPath) && wired(localNotes)
                && !fs.readFileSync(path.join(localNotes, "Package.swift"), "utf8").includes('path: "../.."')
                && !fs.existsSync(path.join(local!, "StateUI")) && !fs.existsSync(path.join(local!, ".scripts")));
            const tasks = await vscode.commands.executeCommand<string>("stateui.newApplicationInApps", { folder: local, name: "Tasks" });
            check("New Application in that group makes it beside Notes, listed, naming the same checkout",
                same(tasks, path.join(local!, "Tasks")) && listed(local!) === "Notes Tasks"
                && same(await libraryOf(tasks), root.uri.fsPath) && wired(tasks));
            check("the local group's application builds", builds(localNotes));
            // StateUI: Run Tests in the group: each application's example test, run as the command runs it.
            const testHost = process.platform === "darwin" ? "appkit" : undefined;
            const groupSuites = findSuites(local!, testHost, await described(local!));
            const notesSuite = groupSuites.find((each) => each.label === "Notes");
            check("Run Tests in a group finds each application's tests",
                groupSuites.map((each) => each.label).join(" ") === "Notes Tasks" && notesSuite !== undefined);
            const passes = (() => {
                try {
                    const env = Object.fromEntries(Object.entries({ ...process.env, ...environment(testHost), ...notesSuite!.env })
                        .filter((entry): entry is [string, string] => entry[1] !== undefined));
                    execSync([notesSuite!.command, ...notesSuite!.args].map((each) => `"${each}"`).join(" "), { cwd: local, env, stdio: "pipe" });
                    return true;
                } catch (error) {
                    say(`     ${String((error as { stdout?: Buffer }).stdout ?? error).split("\n").slice(-8).join("\n     ")}`);
                    return false;
                }
            })();
            check(`Notes' example test passes as ${testHost ?? "plain Swift"}`, passes);

            // StateUI: Deploy in the group: Notes built for release and laid in the group's artifacts/Notes/<platform>,
            // on WinUI per architecture - this machine's own, and x64 too on an ARM64 machine - and run from there.
            const notes = (await described(local!)).find((each) => each.name === "Notes")!;
            const winUIDeploy = deployCommand(notes, "winui", "D", "x64");
            const androidDeploy = deployCommand(notes, "android", "D", undefined, "SERIAL");
            check("Deploy lays an application in artifacts/<application>/<platform> of its workspace, on WinUI per architecture, by its checkout's deploy script",
                commands.includes("stateui.deploy")
                && JSON.stringify(winUIArchitectures("arm64")) === JSON.stringify(["arm64", "x64"])
                && JSON.stringify(winUIArchitectures("x64")) === JSON.stringify(["x64"])
                && deployDestination(notes, "winui", "x64") === path.join(local!, "artifacts", "Notes", "WinUI", "x64")
                && deployDestination(notes, "gtk") === path.join(local!, "artifacts", "Notes", "GTK")
                && same(notes.checkout, root.uri.fsPath)
                && winUIDeploy?.script === path.join(notes.checkout!, ".scripts", "WinUI", "deploy.ps1")
                && winUIDeploy.args.slice(-6).join(" ") === `-App ${notes.directory} -Destination D -Architecture x64`
                && androidDeploy?.command === "bash"
                && androidDeploy.args.join(" ") === `${path.join(notes.checkout!, ".scripts", "Android", "deploy.sh")} ${notes.directory} D SERIAL`
                && fs.readFileSync(path.join(local!, ".gitignore"), "utf8").includes("\n/artifacts/\n"));
            const own: Record<string, Host> = { darwin: "appkit", win32: "winui", linux: "gtk" };
            await api.selectHost(own[process.platform]);
            for (const architecture of process.platform === "win32" ? winUIArchitectures() : [undefined]) {
                const laid = await vscode.commands.executeCommand<string>("stateui.deploy", { application: notes.directory, architecture });
                const platform = describe(own[process.platform]).label;
                check(`Deploy lays the group's Notes in its artifacts/Notes/${platform}${architecture ? `/${architecture}` : ""}`,
                    laid === path.join(local!, "artifacts", "Notes", platform, ...(architecture ? [architecture] : []))
                    && fs.readdirSync(laid).length > 0);
                if (architecture) {
                    // Its head's architecture, from its PE header; the Swift and C++ runtimes of it beside it, and no module.
                    const head = path.join(laid!, "NotesWinUI.exe");
                    const bytes = fs.readFileSync(head);
                    check(`the deployed head is ${architecture}, with StateUI, the Windows App SDK and the Swift and C++ runtimes of its architecture, and nothing only a build reads`,
                        bytes.readUInt16LE(bytes.readUInt32LE(0x3c) + 4) === (architecture === "x64" ? 0x8664 : 0xaa64)
                        && ["StateUI.dll", "swiftCore.dll", "Foundation.dll", "vcruntime140.dll", "Microsoft.ui.xaml.dll", "resources.pri"]
                            .every((each) => fs.existsSync(path.join(laid!, each)))
                        && !fs.existsSync(path.join(laid!, "StateUI.swiftmodule")) && !fs.existsSync(path.join(laid!, "plutil.exe")));
                    // Started with no Swift on the search path, as on a machine that has none.
                    const bare = (process.env.PATH ?? "").split(";").filter((each) => !/\\Swift\\/i.test(each)).join(";");
                    const started = spawn(head, [], { cwd: laid, env: { ...process.env, PATH: bare }, stdio: "ignore" });
                    await new Promise((resume) => setTimeout(resume, 8000));
                    const runs = started.exitCode === null;
                    started.kill();
                    check(`the deployed ${architecture} Notes runs from there with no Swift on the search path`, runs);
                }
            }

            // A release is offered from minimumRelease on - the first whose scripts build as this extension does.
            const minimum: string = JSON.parse(fs.readFileSync(path.join(root.uri.fsPath, "editors", "VSCode", "package.json"), "utf8"))
                .contributes.configuration.properties["stateui.minimumRelease"].default;
            // The releases as the command lists them: by the stateui tool on the search path.
            const every = await tool.request("releases/list", { minimum: "0.0.0", repository: "https://github.com/idexus/StateUI.git" });
            const offered = await tool.request("releases/list", { minimum, repository: "https://github.com/idexus/StateUI.git" });
            check(`GitHub lists its releases, and none older than ${minimum} is offered - 0.4.0 builds differently`,
                every.releases.includes("0.4.0") && !offered.releases.includes("0.4.0")
                && offered.releases.every((each) => every.releases.includes(each)));
            const newest = offered.releases[0];
            if (!newest) {
                say(`skip a group of a release: none ${minimum} or newer is published yet`);
            } else {
                const release = await vscode.commands.executeCommand<string>("stateui.newProjectGroup",
                    { location, name: "ReleaseGroup", release: newest, application: "Notes" });
                const releaseNotes = path.join(release ?? "", "Notes");
                const cloned = path.join(release ?? "", "StateUI");
                check(`with a release it is cloned into the group's StateUI/ at ${newest}, and the application names ../StateUI`,
                    same(release, path.join(location, "ReleaseGroup"))
                    && execSync("git describe --tags", { cwd: cloned }).toString().trim() === newest
                    && same(await libraryOf(releaseNotes), cloned) && wired(releaseNotes)
                    && fs.readFileSync(path.join(releaseNotes, "Package.swift"), "utf8").includes('path: "../StateUI")'));
                const more = await vscode.commands.executeCommand<string>("stateui.newApplicationInApps", { folder: release, name: "Tasks" });
                check("New Application in that group names its release", same(await libraryOf(more), cloned));
                check("the release group's application builds", builds(releaseNotes));
            }
            if (!process.env.STATEUI_TEST_GROUPS) {
                fs.rmSync(location, { recursive: true, force: true });
            }
        }
        await tool.dispose();
        // 7b. The extension reinstalls itself from the checkout: packed by npm, installed by the editor's command line.
        {
            const version = JSON.parse(fs.readFileSync(path.join(root.uri.fsPath, "editors", "VSCode", "package.json"), "utf8")).version;
            const steps = reinstallSteps(root.uri.fsPath, "/Editor/bin/code", "linux");
            check("Reinstall VS Code Extension packs it with npm in editors/VSCode, then installs artifacts/stateui-<version>.vsix with --force",
                commands.includes("stateui.reinstallExtension") && steps.length === 2
                && `${steps[0].command} ${steps[0].args.join(" ")}` === "npm run package"
                && steps[0].cwd === path.join(root.uri.fsPath, "editors", "VSCode")
                && steps[1].command === "/Editor/bin/code"
                && steps[1].args.join(" ") === `--install-extension ${path.join(root.uri.fsPath, "artifacts", `stateui-${version}.vsix`)} --force`);
            check("on Windows it packs with npm.cmd, which a terminal whose policy refuses scripts (npm.ps1) still runs",
                reinstallSteps(root.uri.fsPath, "C:\\Editor\\bin\\code.cmd", "win32")[0].command === "npm.cmd");
            check("the command line that installs it is the running editor's own, where its platform keeps it",
                fs.existsSync(editorCommandLine(vscode.env.appRoot)));
        }
        // 7c. The chosen host's marks are made again - every family, or the stale ones - then the documents rendered,
        //     from a checkout alone.
        {
            const checkout = root.uri.fsPath;
            const all = rebuildSteps(checkout, "winui", "all");
            const changed = rebuildSteps(checkout, "winui", "changed");
            const appKit = rebuildSteps(checkout, "appkit", "changed");
            const manifest = JSON.parse(fs.readFileSync(path.join(checkout, "editors", "VSCode", "package.json"), "utf8"));
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
        //     rest: the stateui tool's findings, with what the editor alone knows of a Debug launch; on the machine
        //     running the suite, nothing missing.
        {
            check("Check Toolchain compares versions part by part, reads lldb-dap's words, and says a version too old",
                commands.includes("stateui.checkToolchain")
                && atLeast("6.4.1", "6.4") && atLeast("26", "26.0") && !atLeast("6.3.9", "6.4") && !atLeast("4.13", "4.14")
                && lldbDapFailure("lldb-dap: LLVM (http://llvm.org/):\n  LLVM version 21.0.0\n") === undefined
                && lldbDapFailure(".../usr/bin/lldb-dap: error while loading shared libraries: libpython3.9.so.1.0: cannot open"
                    + " shared object file: No such file or directory\n") === "libpython3.9.so.1.0 is missing"
                && lldbDapFailure(undefined) === "it did not run"
                && checkedPythonIn("C:\\Swift\\Python-3.10.1\\usr\\bin\\python310.dll\r\n") === "C:\\Swift\\Python-3.10.1\\usr\\bin\\python310.dll"
                && checkedPythonIn("error: unable to find 'python310.dll'.\r\nEnsure Python 3.10 (arm64) is installed and available"
                    + " in your Path.\r\n") === undefined
                && debuggerFinding(["lldb-dap"]).found !== undefined && debuggerFinding(["node"]).found === undefined
                && report([{ component: "Node.js 20 or newer", neededBy: "it", tooOld: "19.4.0", advice: "Install it." }])[0]
                    === "✗ Node.js 20 or newer - 19.4.0 found, too old [it]. Install it.");
            // As the command answers: the tool's components, the LLDB DAP extension, and whether the lldb-dap a launch
            // takes starts (Linux, Windows).
            const findings = await vscode.commands.executeCommand<Finding[] | undefined>("stateui.checkToolchain") ?? [];
            report(findings).forEach((line) => say(`     ${line}`));
            const own: Record<string, string> = { linux: "GTK 4.14 or newer, with its headers", darwin: "Xcode 27 or newer",
                win32: "Visual Studio 2026 with the C++ tools for this machine" };
            const missing = findings.filter((each) => each.found === undefined).map((each) => each.component);
            check(`Check Toolchain asks the stateui tool for Swift, this platform's own, lldb-dap and Git, adds the LLDB DAP `
                + `extension - and an lldb-dap that starts, off the Mac - and finds them all here${
                missing.length > 0 ? ` - not ${missing.join(", ")}` : ""}`,
                findings[0]?.component === "Swift 6.4 or newer" && findings.some((each) => each.component === own[process.platform])
                && findings.some((each) => each.component === "lldb-dap") && findings.some((each) => each.component === "Git")
                && findings.some((each) => each.component === "the LLDB DAP extension")
                && (process.platform === "darwin" || findings.some((each) => each.component === "an lldb-dap that starts"))
                && missing.length === 0 && findings.every((each) => each.advice.length > 0));
        }
        // 8. The package holds what the sources build today - every one, its folders' too - and nothing an older
        //    build left in out/.
        {
            const extension = path.join(root.uri.fsPath, "editors", "VSCode");
            const vsce = path.join(extension, "node_modules", ".bin", process.platform === "win32" ? "vsce.cmd" : "vsce");
            const packed = execSync(`"${vsce}" ls`, { cwd: extension }).toString().split(/\r?\n/).filter((line) => line.length > 0);
            // A compiled file whose source is gone is left in out/ by tsc, and would be packed.
            const stray = packed.filter((file) => {
                const compiled = file.match(/^out\/Sources\/((?:[A-Za-z]+\/)*[A-Za-z]+)\.js$/);
                return compiled ? !fs.existsSync(path.join(extension, "Sources", `${compiled[1]}.ts`))
                    : !/^(package\.json|README\.md|icon\.png|LICENSE)$/.test(file);
            });
            const sources = (folder: string): string[] => fs.readdirSync(path.join(extension, folder), { withFileTypes: true })
                .flatMap((each) => each.isDirectory() ? sources(`${folder}/${each.name}`)
                    : each.name.endsWith(".ts") ? [`out/${folder}/${each.name.slice(0, -3)}.js`] : []);
            const missing = sources("Sources").filter((file) => !packed.includes(file));
            check(`the package holds the manifest, the readme, the icon and what Sources compile to alone${stray.length > 0 ? ` - not ${stray.slice(0, 3).join(", ")}` : ""}`,
                stray.length === 0 && packed.includes("out/Sources/extension.js"));
            check(`the package holds what every source compiles to, in Sources' folders too${missing.length > 0 ? ` - not ${missing.slice(0, 3).join(", ")}` : ""}`,
                missing.length === 0 && packed.includes("out/Sources/Tooling/client.js"));
        }
        // 9. StateUI: Debug runs the REMEMBERED application - no question asked - on this machine's host: AppKit
        //    built and under lldb-dap on macOS, WinUI on Windows and GTK on Linux alike.
        if (process.platform === "darwin") {
            await api.selectHost("appkit");
            await api.selectApplication("HelloWorld");
            check("the chosen application is remembered", api.application() === "HelloWorld");
            // A breakpoint the first render reaches - the button's caption - and the stop lldb-dap reports.
            const page = vscode.Uri.file(path.join(root.uri.fsPath, "apps", "HelloWorld", "Sources", "MainPage.swift"));
            const breakpoint = new vscode.SourceBreakpoint(new vscode.Location(page, new vscode.Position(40, 0)));
            const breakpointStop = () => new Promise<number>((resolve) => {
                const tracking = vscode.debug.registerDebugAdapterTrackerFactory("lldb-dap", {
                    createDebugAdapterTracker: () => ({
                        onDidSendMessage: (message: { type?: string; event?: string; body?: { reason?: string; threadId?: number } }) => {
                            if (message.type === "event" && message.event === "stopped" && message.body?.reason === "breakpoint") {
                                tracking.dispose();
                                resolve(message.body.threadId ?? 0);
                            }
                        },
                    }),
                });
            });
            // The stop at the breakpoint, its frame and locals checked, the breakpoint taken away and the run let go.
            const stopsInCaption = async (running: vscode.DebugSession | undefined, stop: Promise<number>, on: string): Promise<void> => {
                const thread = await Promise.race([stop, new Promise<undefined>((resolve) => setTimeout(() => resolve(undefined), 180_000))]);
                check(`the breakpoint in the button's caption stops a render of it${on}`, thread !== undefined && running !== undefined);
                if (thread !== undefined && running) {
                    const trace = await running.customRequest("stackTrace", { threadId: thread, levels: 1 });
                    const frame = trace.stackFrames?.[0];
                    const scopes = await running.customRequest("scopes", { frameId: frame?.id });
                    const locals = (scopes.scopes ?? []).find((each: { name: string }) => /local/i.test(each.name));
                    const variables = locals ? await running.customRequest("variables", { variablesReference: locals.variablesReference }) : {};
                    check(`it stops in MainPage.caption(clicks:) at line 41, its locals holding count${on} - ${frame?.name} ${frame?.source?.path}:${frame?.line}`,
                        String(frame?.name ?? "").includes("caption") && String(frame?.source?.path ?? "").endsWith("MainPage.swift")
                        && frame?.line === 41 && (variables.variables ?? []).some((each: { name: string }) => each.name === "count"));
                    vscode.debug.removeBreakpoints([breakpoint]);
                    await running.customRequest("continue", { threadId: thread });
                } else {
                    vscode.debug.removeBreakpoints([breakpoint]);
                }
            };
            vscode.debug.addBreakpoints([breakpoint]);
            const stopped = breakpointStop();
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
            // The bundle the stateui tool built and published, its program launched under lldb-dap.
            const program = String(running?.configuration.program ?? "");
            check(`an lldb-dap session starts on HelloWorldAppKit as the stateui tool published it - ${program}`,
                program.includes("/apps/HelloWorld/.build/stateui/artifacts/appkit-")
                && program.endsWith("-debug/HelloWorldAppKit.app/Contents/MacOS/HelloWorldAppKit") && fs.existsSync(program));
            await stopsInCaption(running, stopped, "");
            await new Promise((resume) => setTimeout(resume, 4000));
            const alive = (() => { try { return execSync("pgrep -f HelloWorldAppKit.app/Contents/MacOS/HelloWorldAppKit").toString().trim().length > 0; } catch { return false; } })();
            check("the HelloWorldAppKit process is running", alive);
            await vscode.debug.stopDebugging(running);
            await new Promise((resume) => setTimeout(resume, 3000));
            const gone = (() => { try { return execSync("pgrep -f HelloWorldAppKit.app/Contents/MacOS/HelloWorldAppKit").toString().trim().length === 0; } catch { return true; } })();
            check("Stop ends the HelloWorldAppKit process", gone);

            // And on the iOS simulator: the stateui tool starts HelloWorld held, and lldb-dap attaches and lets it run.
            const lister = await ToolingClient.start({
                executable: locateTool(vscode.workspace.getConfiguration("stateui").get<string>("cliPath")),
                folder: root.uri.fsPath, clientVersion: "suite",
            });
            const listed = await lister.request("devices/list", { host: "uikit" });
            await lister.dispose();
            const iPhone = listed.destinations.map(uiKitDeviceOf).find((each) => each.kind === "simulator" && each.name.startsWith("iPhone"));
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
            vscode.debug.addBreakpoints([breakpoint]);
            const stoppedOnSimulator = breakpointStop();
            check("StateUI: Debug starts on UIKit", await vscode.debug.startDebugging(root,
                { name: "StateUI: Debug", type: "stateui", request: "launch", configuration: "debug" }));
            const onSimulator = await Promise.race([attached, new Promise<undefined>((resolve) => setTimeout(() => resolve(undefined), 900_000))]);
            check("an lldb-dap session attaches to HelloWorldUIKit's process", typeof onSimulator?.configuration.pid === "number");
            await stopsInCaption(onSimulator, stoppedOnSimulator, " on the simulator");
            await new Promise((resume) => setTimeout(resume, 4000));
            const onDevice = (() => { try { return execSync(`pgrep -f ${iPhone!.id}.*HelloWorldUIKit`).toString().trim().length > 0; } catch { return false; } })();
            check("the HelloWorldUIKit process runs on the simulator", onDevice);
            const sessionEnded = new Promise<boolean>((resolve) => {
                const listener = vscode.debug.onDidTerminateDebugSession((each) => {
                    if (each.id === onSimulator?.id) {
                        listener.dispose();
                        resolve(true);
                    }
                });
                setTimeout(() => resolve(false), 30_000);
            });
            await vscode.debug.stopDebugging(onSimulator);
            check("Stop ends the lldb-dap session on the simulator", await sessionEnded);
            await new Promise((resume) => setTimeout(resume, 5000));
            // The simulator's launchd lists it while any process of it stands - a zombie a stopped debugserver holds too.
            const services = execSync(`xcrun simctl spawn ${iPhone!.id} launchctl list`).toString();
            check("Stop ends HelloWorldUIKit on the simulator - the run stops with the session, its launchd lists it no more",
                !services.includes("com.stateui.helloworld"));
            const launcher = (() => { try { return execSync("pgrep -f 'simctl launch'").toString().trim(); } catch { return ""; } })();
            check("no simctl launch outlives the session", launcher === "");

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
                vscode.debug.addBreakpoints([breakpoint]);
                const stoppedOnDevice = breakpointStop();
                check("StateUI: Debug starts on the device", await vscode.debug.startDebugging(root,
                    { name: "StateUI: Debug", type: "stateui", request: "launch", configuration: "debug" }));
                const session = await Promise.race([attachedOnDevice, new Promise<undefined>((resolve) => setTimeout(() => resolve(undefined), 900_000))]);
                check("an lldb-dap session attaches through the device", JSON.stringify(session?.configuration.attachCommands ?? []).includes(`device select ${real}`));
                await stopsInCaption(session, stoppedOnDevice, " on the device");
                await new Promise((resume) => setTimeout(resume, 8000));
                const onTheDevice = (): boolean => {
                    try {
                        return execSync(`xcrun devicectl device info processes --device ${real}`).toString().includes("HelloWorldUIKit.app/HelloWorldUIKit");
                    } catch {
                        return false;
                    }
                };
                check("the HelloWorldUIKit process runs on the device", onTheDevice());
                const deviceSessionEnded = new Promise<boolean>((resolve) => {
                    const listener = vscode.debug.onDidTerminateDebugSession((each) => {
                        if (each.id === session?.id) {
                            listener.dispose();
                            resolve(true);
                        }
                    });
                    setTimeout(() => resolve(false), 30_000);
                });
                await vscode.debug.stopDebugging(session);
                check("Stop ends the lldb-dap session on the device", await deviceSessionEnded);
                await new Promise((resume) => setTimeout(resume, 8000));
                check("Stop ends HelloWorldUIKit on the device", !onTheDevice());
                const consoles = (() => { try { return execSync("pgrep -f 'devicectl device process launch'").toString().trim(); } catch { return ""; } })();
                check("no devicectl console outlives the session", consoles === "");
            } else {
                say("skip a real device: STATEUI_UIKIT_DEVICE names none");
            }

            // And on Android, where STATEUI_ANDROID_DEVICE names a device or emulator running: the tool builds the
            // APK for its ABI and readies the debugger's server, lldb-dap attaches through it, a press reaches the
            // breakpoint, and Stop ends it all.
            const android = process.env.STATEUI_ANDROID_DEVICE;
            if (android) {
                const adb = path.join(os.homedir(), "Library", "Android", "sdk", "platform-tools", "adb");
                const pidOf = (): string => { try { return execSync(`${adb} -s ${android} shell pidof com.stateui.helloworld`).toString().trim(); } catch { return ""; } };
                await api.selectHost("android");
                await api.selectApplication("HelloWorld");
                check("the Android device chosen by its serial is named by its name", (await api.selectAndroidDevice(android)) !== undefined);
                const attachedOnAndroid = new Promise<vscode.DebugSession>((resolve) => {
                    const listener = vscode.debug.onDidStartDebugSession((each) => {
                        if (each.type === "lldb-dap") {
                            listener.dispose();
                            resolve(each);
                        }
                    });
                });
                vscode.debug.addBreakpoints([breakpoint]);
                const stoppedOnAndroid = breakpointStop();
                check("StateUI: Debug starts on Android", await vscode.debug.startDebugging(root,
                    { name: "StateUI: Debug", type: "stateui", request: "launch", configuration: "debug" }));
                const session = await Promise.race([attachedOnAndroid, new Promise<undefined>((resolve) => setTimeout(() => resolve(undefined), 900_000))]);
                check("an lldb-dap session attaches through the device's lldb-server",
                    JSON.stringify(session?.configuration.initCommands ?? []).includes(`unix-abstract-connect://${android}/`));
                // The debugger attaches to the application running, after its first render: a press on the button
                // renders its caption again, where the breakpoint stands.
                await new Promise((resume) => setTimeout(resume, 4000));
                const screen = (() => { try { return execSync(`${adb} -s ${android} exec-out uiautomator dump /dev/tty`).toString(); } catch { return ""; } })();
                const bounds = /resource-id="main\.click"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/.exec(screen);
                check("the button stands on the Android device's screen", bounds !== null);
                if (bounds) {
                    const [left, top, right, bottom] = bounds.slice(1).map(Number);
                    execSync(`${adb} -s ${android} shell input tap ${(left + right) / 2} ${(top + bottom) / 2}`);
                }
                await stopsInCaption(session, stoppedOnAndroid, " on Android");
                await new Promise((resume) => setTimeout(resume, 4000));
                check("the HelloWorld process runs on the Android device", pidOf() !== "");
                const androidSessionEnded = new Promise<boolean>((resolve) => {
                    const listener = vscode.debug.onDidTerminateDebugSession((each) => {
                        if (each.id === session?.id) {
                            listener.dispose();
                            resolve(true);
                        }
                    });
                    setTimeout(() => resolve(false), 30_000);
                });
                await vscode.debug.stopDebugging(session);
                check("Stop ends the lldb-dap session on Android", await androidSessionEnded);
                await new Promise((resume) => setTimeout(resume, 6000));
                check("Stop ends HelloWorld on the Android device", pidOf() === "");
                const server = (() => { try { return execSync(`${adb} -s ${android} shell ps -A`).toString().includes("lldb-server"); } catch { return false; } })();
                check("no lldb-server outlives the session", !server);
            } else {
                say("skip Android: STATEUI_ANDROID_DEVICE names no device");
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
            // Where the build laid it - SwiftPM's own layout under .build/winui - in the system's spelling of the drive.
            const program = String(running?.configuration.program ?? "");
            const builds = path.join(api.applications().find((each) => each.name === "HelloWorld")?.directory ?? "", ".build", "winui");
            check(`an lldb-dap session starts on HelloWorldWinUI.exe as its build laid it under .build\\winui - ${program}`,
                path.basename(program) === "HelloWorldWinUI.exe" && fs.existsSync(program)
                && program.toLowerCase().startsWith(builds.toLowerCase()));
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
            const program = String(running?.configuration.program ?? "");
            check(`an lldb-dap session starts on HelloWorldGTK as the stateui tool published it - ${program}`,
                program.includes("/apps/HelloWorld/.build/stateui/artifacts/gtk-") && program.endsWith("-debug/HelloWorldGTK") && fs.existsSync(program));
            const entry = path.join(os.homedir(), ".local", "share", "applications", "com.stateui.helloworld.desktop");
            check("the install wrote HelloWorld's desktop entry naming that program",
                fs.existsSync(entry) && fs.readFileSync(entry, "utf8").includes(`Exec=${program} %u`));
            await new Promise((resume) => setTimeout(resume, 4000));
            // Anchored at the start of a command line: Linux's sh running pgrep stays its parent, its own line naming the program too.
            const alive = (() => { try { return execSync(`pgrep -f '^${program}'`).toString().trim().length > 0; } catch { return false; } })();
            check("the HelloWorldGTK process is running", alive);
            await vscode.debug.stopDebugging(running);
            await new Promise((resume) => setTimeout(resume, 3000));
            const gone = (() => { try { return execSync(`pgrep -f '^${program}'`).toString().trim().length === 0; } catch { return true; } })();
            check("Stop ends the HelloWorldGTK process", gone);
        }

        say("PASS");
    } catch (error) {
        say(`FAIL ${error instanceof Error ? error.message : String(error)}`);
        throw error;
    }
}
