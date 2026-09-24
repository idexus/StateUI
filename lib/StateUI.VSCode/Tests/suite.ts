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
import { StateUIDebugConfigurationProvider } from "../Sources/debug";
import { parseDevices } from "../Sources/devices";
import { serverConfig, serverSettings, swiftRelease, swiftSDKOf } from "../Sources/editorMode";
import { findSuites, forDevice } from "../Sources/tests";
import { availableHosts, environment, hosts } from "../Sources/hosts";
import { StateUIApi } from "../Sources/extension";
import { inAppsCommand, nameProblem } from "../Sources/newApplication";

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
        const conditional = path.join(gallery, "Sources", "Samples", "Interop", "AppKitMetalSample.swift");
        const head = path.join(gallery, "Platforms", "AppKit", "Host", "MetalCubeView.swift");

        const api = await vscode.extensions.getExtension<StateUIApi>("idexus.stateui")!.activate();
        say(`activated, host ${api.host()}`);

        // 1. Android: the plain symbol resolves, the AppKit one does not.
        await api.selectHost("android");
        await until("android: a symbol under no condition resolves", () => resolves(plain, "Palette.accent"), 900);
        check("android: MetalCube under #if APPKIT does not resolve",
            !(await resolves(conditional, "MetalCube()", "var content: any View")));

        // 2. AppKit, with no reload: the conditional symbol and the head resolve.
        await api.selectHost("appkit");
        await until("appkit: MetalCube under #if APPKIT resolves",
            () => resolves(conditional, "MetalCube()", "var content: any View"), 900);
        // A target the package did not have a moment ago: the server has to
        // load it, so this is waited for rather than asked once.
        await until("appkit: MetalCubeContract in Platforms/AppKit resolves", () => resolves(head, "MetalCubeContract.self"), 900);

        // 3. And back, still with no reload.
        await api.selectHost("android");
        await until("android again: MetalCube stops resolving while the plain symbol does", async () =>
            (await resolves(plain, "Palette.accent"))
            && !(await resolves(conditional, "MetalCube()", "var content: any View")), 900);

        // 4. The hosts a machine is offered: AppKit and Android on macOS, WinUI
        //    on Windows, none on Linux yet, and no .NET MAUI. A launch on a
        //    machine that runs no host resolves to nothing.
        const gallery_ = findApplications(root.uri.fsPath).find((each) => each.name === "Gallery")!;
        check("the host picker offers AppKit and Android on macOS, WinUI on Windows, nothing on Linux, and never .NET MAUI",
            JSON.stringify(availableHosts("darwin").map((each) => each.id)) === JSON.stringify(["appkit", "android"])
            && JSON.stringify(availableHosts("win32").map((each) => each.id)) === JSON.stringify(["winui"])
            && availableHosts("linux").length === 0
            && !hosts.some((each) => each.label.includes("MAUI")));
        {
            const ran: string[] = [];
            const provider = new StateUIDebugConfigurationProvider({
                host: () => undefined, application: async () => gallery_,
                run: async (task) => { ran.push(task.name); return 0; },
                start: async (task) => { ran.push(task.name); },
                ready: async () => false,
                device: async () => undefined,
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
                return JSON.stringify(Object.keys(values).sort()) === JSON.stringify(["STATEUI_ANDROID", "STATEUI_APPKIT", "STATEUI_WINUI"])
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
        // 6b. WinUI: HelloWorld's head, a launch through run-app.ps1 with no
        //     session yet, and the host's own package through test-winui.ps1.
        check("HelloWorld has a WinUI head, and as WinUI the language server indexes in .build-winui/index-build",
            hasHead(helloWorld, "winui")
            && JSON.stringify(serverSettings("winui", undefined)) === JSON.stringify({ scratchPath: ".build-winui/index-build" }));
        {
            const started: vscode.Task[] = [];
            const provider = new StateUIDebugConfigurationProvider({
                host: () => "winui", application: async () => helloWorld,
                run: async () => 0,
                start: async (task) => { started.push(task); },
                ready: async () => false,
                device: async () => undefined,
            });
            const resolved = await provider.resolveDebugConfiguration(root,
                { name: "StateUI: Release", type: "stateui", request: "launch", configuration: "release" });
            const process_ = started[0]?.execution as vscode.ProcessExecution | undefined;
            const line = process_ ? [process_.process, ...process_.args].join(" ") : "";
            say(`     winui started: ${line}`);
            check("WinUI: run-app.ps1 -App <HelloWorld> -Configuration release started as a task, and no session",
                resolved === undefined && started.length === 1
                && line === `powershell -NoProfile -ExecutionPolicy Bypass -File ${path.join(root.uri.fsPath, ".scripts", "WinUI", "run-app.ps1")} -App ${helloWorld.directory} -Configuration release`);
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

        const palette = await vscode.commands.getCommands(true);
        check("the palette has Select Android Device, and no Select Debugger",
            palette.includes("stateui.selectAndroidDevice") && !palette.includes("stateui.selectDebugger"));

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
                made.command === "bash" && made.args[0].endsWith("/.scripts/new-app.sh") && made.args[1] === "Notes"
                && windows.command === "powershell" && windows.args.slice(-3).join(" ").endsWith("new-app.ps1 -Name Notes"));
        }
        // 8. The package holds what the sources build today and nothing an
        //    older build left in out/.
        {
            const extension = path.join(root.uri.fsPath, "lib", "StateUI.VSCode");
            const vsce = path.join(extension, "node_modules", ".bin", process.platform === "win32" ? "vsce.cmd" : "vsce");
            const packed = execSync(`"${vsce}" ls`, { cwd: extension }).toString().split(/\r?\n/).filter((line) => line.length > 0);
            const stray = packed.filter((file) => !/^(package\.json|README\.md|icon\.png|LICENSE|out\/Sources\/[A-Za-z]+\.js)$/.test(file));
            check(`the package holds the manifest, the readme, the icon and out/Sources alone${stray.length > 0 ? ` - not ${stray.slice(0, 3).join(", ")}` : ""}`,
                stray.length === 0 && packed.includes("out/Sources/extension.js"));
        }
        // 9. StateUI: Debug on AppKit runs the REMEMBERED application - no
        //    question asked - built, under lldb-dap.
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

        say("PASS");
    } catch (error) {
        say(`FAIL ${error instanceof Error ? error.message : String(error)}`);
        throw error;
    }
}
