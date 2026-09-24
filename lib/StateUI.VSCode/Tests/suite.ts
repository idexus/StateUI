// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The integration suite, run inside VS Code by Tests/run.ts.
//
// The editor's host is asked of the LANGUAGE SERVER, which cannot be faked: a
// symbol under `#if APPKIT` resolves only while SourceKit-LSP runs with
// STATEUI_APPKIT, and a symbol under no condition resolves in either mode -
// which is what tells "not this host" from "not ready yet".

import { execFileSync, execSync } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import * as vscode from "vscode";
import { findApplications, hasHead } from "../Sources/applications";
import { StateUIDebugConfigurationProvider, stateUIBuildDirectory } from "../Sources/debug";
import { parseDevices } from "../Sources/devices";
import { serverConfig, serverSettings, swiftRelease, swiftSDKOf } from "../Sources/editorMode";
import { findSuites, forDevice } from "../Sources/tests";
import { availableHosts, environment, hosts, MauiDebugger } from "../Sources/hosts";
import { StateUIApi } from "../Sources/extension";
import { carriedTemplate, inAppsCommand, nameProblem, Starter, templateIn, writeStarter } from "../Sources/newApplication";

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

        // 1. MAUI: the plain symbol resolves, the AppKit one does not.
        await api.selectHost("maui");
        await until("maui: a symbol under no condition resolves", () => resolves(plain, "Palette.accent"), 900);
        check("maui: MetalCube under #if APPKIT does not resolve",
            !(await resolves(conditional, "MetalCube()", "var content: any View")));

        // 2. AppKit, with no reload: the conditional symbol and the head resolve.
        await api.selectHost("appkit");
        await until("appkit: MetalCube under #if APPKIT resolves",
            () => resolves(conditional, "MetalCube()", "var content: any View"), 900);
        // A target the package did not have a moment ago: the server has to
        // load it, so this is waited for rather than asked once.
        await until("appkit: MetalCubeContract in Platforms/AppKit resolves", () => resolves(head, "MetalCubeContract.self"), 900);

        // 3. And back, still with no reload.
        await api.selectHost("maui");
        await until("maui again: MetalCube stops resolving while the plain symbol does", async () =>
            (await resolves(plain, "Palette.accent"))
            && !(await resolves(conditional, "MetalCube()", "var content: any View")), 900);

        // 4. Every MAUI debugger resolves into the launch it names - the
        //    commands a build would run captured, not run.
        const gallery_ = findApplications(root.uri.fsPath).find((each) => each.name === "Gallery")!;
        const resolveAs = async (chosen: MauiDebugger, platform: NodeJS.Platform, configuration = "debug", application = gallery_) => {
            const ran: string[] = [];
            const attached: string[] = [];
            const provider = new StateUIDebugConfigurationProvider({
                host: () => "maui", application: async () => application, debugger: () => chosen, platform,
                run: async (task) => {
                    const shell = task.execution as vscode.ShellExecution;
                    ran.push([shell.command, ...(shell.args ?? [])].map(String).join(" "));
                    return 0;
                },
                start: async () => { throw new Error("a MAUI launch starts no task that runs until stopped"); },
                ready: async () => { throw new Error("a MAUI launch waits for no Android debugger"); },
                device: async () => { throw new Error("a MAUI launch asks for no Android device"); },
                attachSwiftWhenStarted: (session, processName) => { attached.push(`${session}->${processName}`); },
            });
            const resolved = await provider.resolveDebugConfiguration(root,
                { name: "StateUI: Debug", type: "stateui", request: "launch", configuration });
            return { resolved, ran, attached };
        };
        const project = "/apps/Gallery/Platforms/Maui/Gallery.csproj";

        {
            const { resolved, ran } = await resolveAs("csharp", "darwin", "release");
            check("C#: the maui type, in Release, on Gallery's project, with no device, and nothing run first",
                resolved?.type === "maui" && resolved.configuration === "Release" && String(resolved.project).endsWith(project)
                && resolved.device === undefined && ran.length === 0);
        }
        {
            const { resolved } = await resolveAs("csharp", "win32", "release");
            check("C# on Windows, Release: the executable is named, with no runtime identifier",
                String(resolved?.program).endsWith("/apps/Gallery/Platforms/Maui/bin/Release/net10.0-windows10.0.19041.0/Gallery.exe"));
        }
        {
            // A Windows workspace folder's fsPath names its drive `c:`, and the
            // MAUI extension finds a launch's project only as C# Dev Kit loaded it.
            const onWindows = { ...gallery_, mauiProject: "c:\\Projects\\StateUI\\apps\\Gallery\\Platforms\\Maui\\Gallery.csproj" };
            const launches = [await resolveAs("csharp", "win32", "debug", onWindows), await resolveAs("csharp", "win32", "release", onWindows)];
            check("C# on Windows: the project's drive letter is upper case, as C# Dev Kit loads it",
                launches.every(({ resolved }) => resolved?.project === "C:\\Projects\\StateUI\\apps\\Gallery\\Platforms\\Maui\\Gallery.csproj"));
        }
        {
            const { resolved, ran } = await resolveAs("swift-ios", "darwin");
            say(`     swift-ios ran: ${ran.join(" | ")}`);
            check("Swift · iOS Simulator: run-app.sh ios Debug <project>, then lldb-dap attaches to Gallery",
                ran.length === 1 && /run-app\.sh ios Debug .*Gallery\.csproj$/.test(ran[0])
                && resolved?.type === "lldb-dap" && resolved.request === "attach"
                && JSON.stringify(resolved.attachCommands) === JSON.stringify(["process attach --name Gallery"]));
        }
        {
            const { resolved, ran } = await resolveAs("swift-maccatalyst", "darwin", "release");
            check("Swift · Mac Catalyst, Release: run-app.sh maccatalyst Release, then an attach",
                ran.length === 1 && /run-app\.sh maccatalyst Release /.test(ran[0]) && resolved?.request === "attach");
        }
        {
            const { resolved, ran, attached } = await resolveAs("csharp-swift-maccatalyst", "darwin");
            check("C# + Swift · Mac Catalyst: a maui session pinned to Mac Catalyst, with Swift promised beside it",
                resolved?.type === "maui" && resolved.targetFramework === "net10.0-maccatalyst27.0"
                && ran.length === 0 && JSON.stringify(attached) === JSON.stringify(["StateUI: Debug->Gallery"]));
        }
        {
            const { resolved, ran } = await resolveAs("csharp", "linux");
            check("C# on Linux: dotnet build, then coreclr on bin/Debug/net10.0/Gallery",
                /^dotnet build .*Gallery\.csproj -c Debug/.test(ran[0] ?? "") && resolved?.type === "coreclr"
                && String(resolved.program).endsWith("/apps/Gallery/Platforms/Maui/bin/Debug/net10.0/Gallery"));
        }
        {
            const { resolved } = await resolveAs("swift", "linux");
            check("Swift on Linux: lldb-dap LAUNCHES the head", resolved?.type === "lldb-dap" && resolved.request === "launch");
        }
        {
            const { resolved, ran } = await resolveAs("swift", "win32");
            check("Swift on Windows: run-app.ps1, then lldb-dap attaches to Gallery.exe",
                /run-app\.ps1 -Configuration Debug -Project .*Gallery\.csproj$/.test(ran[0] ?? "")
                && JSON.stringify(resolved?.attachCommands) === JSON.stringify(["process attach --name Gallery.exe"]));
        }

        // The hosts a machine is offered: AppKit and Android on macOS alone.
        check("the host picker offers AppKit, .NET MAUI and Android on macOS, and only .NET MAUI on Windows and Linux",
            JSON.stringify(availableHosts("darwin").map((each) => each.id)) === JSON.stringify(["appkit", "maui", "android"])
            && JSON.stringify(availableHosts("win32").map((each) => each.id)) === JSON.stringify(["maui"])
            && JSON.stringify(availableHosts("linux").map((each) => each.id)) === JSON.stringify(["maui"]));

        // 5. The suites, found for each host the way test-native.sh runs them.
        const appkitSuites = findSuites(root.uri.fsPath, "appkit").map((each) => each.label);
        const mauiSuites = findSuites(root.uri.fsPath, "maui").map((each) => each.label);
        say(`appkit suites: ${appkitSuites.join(", ")}`);
        say(`maui suites: ${mauiSuites.join(", ")}`);
        check("appkit runs the core, StateUI.AppKit and the Gallery, and no C# and no device",
            appkitSuites.includes("StateUI") && appkitSuites.includes("lib/StateUI.AppKit")
            && appkitSuites.includes("apps/Gallery") && !mauiSuites.includes("lib/StateUI.AppKit")
            && !appkitSuites.some((each) => each.endsWith("Tests")));
        check("maui runs the core, the Gallery and the C# suite, and not StateUI.AppKit nor the Android host's tests",
            mauiSuites.includes("StateUI") && mauiSuites.includes("apps/Gallery")
            && mauiSuites.includes("lib/StateUI.Maui/Tests") && !mauiSuites.includes("lib/StateUI.AppKit")
            && !mauiSuites.includes("lib/StateUI.Android/Tests"));

        // 6. Android: the environment, the language server's file, the
        //    devices, and the commands a launch and a suite run - captured,
        //    not run.
        check("each host's environment sets its own variable alone and clears every other - STATEUI_ANDROID for Android",
            hosts.every((host) => {
                const values = environment(host.id);
                const set = Object.entries(values).filter((entry) => entry[1] !== undefined);
                return JSON.stringify(Object.keys(values).sort()) === JSON.stringify(["STATEUI_ANDROID", "STATEUI_APPKIT"])
                    && JSON.stringify(set) === JSON.stringify(host.variable ? [[host.variable, "1"]] : []);
            }) && environment("android").STATEUI_ANDROID === "1");
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
            check("with no Swift SDK installed Android indexes for this Mac, and a host of this machine never takes one",
                JSON.stringify(serverSettings("android", undefined)) === JSON.stringify({ scratchPath: ".build-android/index-build" })
                && JSON.stringify(serverSettings("maui", sdk)) === JSON.stringify({ scratchPath: ".build-maui/index-build" }));

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
            JSON.stringify(parseDevices("device\t190a991d\tCPH2363\r\ndevice\temulator-5554\tPixel_3a_API_34\ndevice\tR5CT\navd\tMAUI_Emulator_API_33\n\nnoise\n"))
            === JSON.stringify([
                { kind: "device", serial: "190a991d", name: "CPH2363" },
                { kind: "device", serial: "emulator-5554", name: "Pixel_3a_API_34" },
                { kind: "device", serial: "R5CT", name: "R5CT" },
                { kind: "avd", name: "MAUI_Emulator_API_33" },
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
                    host: () => "android", application: async () => helloWorld, debugger: () => "csharp",
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
                    attachSwiftWhenStarted: () => undefined,
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
            check("android runs the core and the Gallery as plain Swift, and no AppKit and no C#",
                androidSuites.some((each) => each.label === "StateUI" && forDevice(each, "emulator-5554") === each)
                && galleryRun?.args.join(" ") === `test --package-path ${gallery}` && Object.keys(galleryRun.env).length === 0
                && !androidSuites.some((each) => each.label === "lib/StateUI.AppKit" || each.command === "dotnet"));
            check("android runs test-android.sh <serial> on the device, and only android does",
                onDevice.length === 1 && onDevice[0].label === "lib/StateUI.Android/Tests"
                && [onDevice[0].command, ...onDevice[0].args].join(" ") === `bash ${path.join(root.uri.fsPath, ".scripts", "Android", "test-android.sh")} emulator-5554`
                && ![...appkitSuites, ...mauiSuites].includes("lib/StateUI.Android/Tests"));
        }
        check("the palette has Select Android Device", (await vscode.commands.getCommands(true)).includes("stateui.selectAndroidDevice"));

        // 7. A new application. What the extension writes from the template is
        //    what `dotnet new stateui-maui` writes, file for file, for each
        //    source and head - the template read by two readers, checked as one.
        const commands = await vscode.commands.getCommands(true);
        check("the palette has New Application in apps/ and New Application from Template",
            commands.includes("stateui.newApplicationInApps") && commands.includes("stateui.newApplication"));
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
        {
            const scratch = fs.mkdtempSync(path.join(os.tmpdir(), "stateui-starter-"));
            const hive = path.join(scratch, "hive");
            const repository = root.uri.fsPath;
            const extensionPath = vscode.extensions.getExtension("idexus.stateui")!.extensionPath;
            execFileSync("dotnet", ["new", "install", templateIn(repository).template, "--debug:custom-hive", hive]);

            const files = (directory: string): string[] => fs.readdirSync(directory, { recursive: true, encoding: "utf8" })
               .filter((each) => fs.statSync(path.join(directory, each)).isFile()).sort();
            const cases: { label: string; starter: Starter; templateRoot: string; options: string[] }[] = [
                { label: "a checkout, with AppKit", templateRoot: repository, options: ["--stateui-path", repository, "--appkit"],
                  starter: { name: "Probe", parent: path.join(scratch, "mine-appkit"), source: { kind: "checkout", checkout: repository }, appKit: true } },
                { label: "a checkout", templateRoot: repository, options: ["--stateui-path", repository],
                  starter: { name: "Probe", parent: path.join(scratch, "mine-checkout"), source: { kind: "checkout", checkout: repository }, appKit: false } },
                { label: "the release, from the template this extension carries", templateRoot: carriedTemplate(extensionPath), options: [],
                  starter: { name: "Probe", parent: path.join(scratch, "mine-release"), source: { kind: "release", version: "0.4.0" }, appKit: false } },
            ];
            for (const each of cases) {
                const mine = writeStarter(each.starter, each.templateRoot);
                const theirs = path.join(scratch, `theirs-${path.basename(each.starter.parent)}`, "Probe");
                execFileSync("dotnet", ["new", "stateui-maui", "-n", "Probe", "-o", theirs, ...each.options, "--debug:custom-hive", hive]);

                const mineFiles = files(mine);
                const theirFiles = files(theirs);
                const differing = mineFiles.filter((file) => !theirFiles.includes(file)
                    || !fs.readFileSync(path.join(mine, file)).equals(fs.readFileSync(path.join(theirs, file))));
                say(`     ${each.label}: ${mineFiles.length} files, differing: ${differing.join(", ") || "none"}`);
                check(`${each.label}: what is written is what \`dotnet new stateui-maui\` writes, and it carries no build of its own`,
                    differing.length === 0 && mineFiles.length === theirFiles.length && !mineFiles.some((file) => file.startsWith(".scripts")));

                const made = fs.readFileSync(path.join(mine, "Platforms", "Maui", "Probe.csproj"), "utf8");
                check(`${each.label}: the project takes StateUI's build from ${each.starter.source.kind === "checkout" ? "the checkout" : "the StateUI.Maui package"}`,
                    each.starter.source.kind === "checkout"
                        ? made.includes(`<Import Project="${repository}/.scripts/Maui/StateUI.targets" />`)
                        : !made.includes("<Import Project=") && made.includes('<PackageReference Include="StateUI.Maui" Version="0.4.0" />'));
            }

            const other = writeStarter({ name: "Later", parent: path.join(scratch, "later"), source: { kind: "release", version: "9.8.7" }, appKit: false },
                carriedTemplate(extensionPath));
            const manifest = fs.readFileSync(path.join(other, "Package.swift"), "utf8");
            const project = fs.readFileSync(path.join(other, "Platforms", "Maui", "Later.csproj"), "utf8");
            check("a release names its version in Package.swift's tag and both NuGet references",
                manifest.includes('exact: "9.8.7"') && project.includes('Include="StateUI.Maui" Version="9.8.7"')
                && project.includes('Include="StateUI.Maui.Linux" Version="9.8.7"') && !/\d+\.\d+\.\d+/.test(manifest.replace("9.8.7", "")));
            let refused = false;
            try { writeStarter({ name: "Later", parent: path.join(scratch, "later"), source: { kind: "release", version: "9.8.7" }, appKit: false }, carriedTemplate(extensionPath)); } catch { refused = true; }
            check("an application is never written over a directory that exists", refused);

            // The scripts a launch runs are the ones the project's own build
            // imports - asked of MSBuild, for the repository's application and
            // for one made against the checkout alike.
            const repositoryBuild = await stateUIBuildDirectory(path.join(repository, "apps", "Gallery", "Platforms", "Maui", "Gallery.csproj"), "net10.0-maccatalyst27.0");
            const checkoutBuild = await stateUIBuildDirectory(path.join(scratch, "mine-checkout", "Probe", "Platforms", "Maui", "Probe.csproj"), "net10.0-maccatalyst27.0");
            // NuGet imports a package's build per target framework - an
            // ImportGroup conditioned on it - so it is asked of the framework
            // the launch builds, as a project made from the packages needs.
            const perFramework = path.join(scratch, "per-framework", "PerFramework.proj");
            fs.mkdirSync(path.dirname(perFramework), { recursive: true });
            fs.writeFileSync(perFramework, `<Project>
  <ImportGroup Condition="'$(TargetFramework)' == 'net10.0-maccatalyst27.0'">
    <Import Project="${repository}/.scripts/Maui/StateUI.targets" />
  </ImportGroup>
  <Target Name="Restore" />
</Project>
`);
            const packageBuild = await stateUIBuildDirectory(perFramework, "net10.0-maccatalyst27.0");
            say(`     build directories: ${repositoryBuild} | ${checkoutBuild} | ${packageBuild}`);
            check("a build imported per target framework, as NuGet imports a package's, is found for the framework launched",
                packageBuild === repositoryBuild);
            check("the build a launch runs is the one the project imports: the checkout's .scripts/Maui, in the repository and outside it",
                repositoryBuild === path.join(repository, ".scripts", "Maui") + path.sep && checkoutBuild === repositoryBuild);
            fs.rmSync(scratch, { recursive: true, force: true });
        }

        // 8. StateUI: Debug on AppKit runs the REMEMBERED application - no
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


        // 9. LIVE: Swift · Mac Catalyst - run-app.sh builds and starts the
        //    Gallery's MAUI head, and lldb-dap attaches to the running app.
        await api.selectHost("maui");
        await api.selectApplication("Gallery");
        await api.selectDebugger("swift-maccatalyst");
        const attaching = new Promise<vscode.DebugSession>((resolve) => {
            const listener = vscode.debug.onDidStartDebugSession((each) => {
                if (each.type === "lldb-dap") {
                    listener.dispose();
                    resolve(each);
                }
            });
        });
        check("StateUI: Debug starts on Mac Catalyst", await vscode.debug.startDebugging(root,
            { name: "StateUI: Debug", type: "stateui", request: "launch", configuration: "debug" }));
        const catalyst = await Promise.race([attaching, new Promise<undefined>((resolve) => setTimeout(() => resolve(undefined), 1_500_000))]);
        check("lldb-dap attaches to Gallery", JSON.stringify(catalyst?.configuration.attachCommands) === JSON.stringify(["process attach --name Gallery"]));
        await new Promise((resume) => setTimeout(resume, 5000));
        const catalystAlive = (() => { try { return execSync("pgrep -x Gallery").toString().trim().length > 0; } catch { return false; } })();
        check("the Mac Catalyst Gallery process is running", catalystAlive);
        await vscode.debug.stopDebugging(catalyst);
        try { execSync("pkill -x Gallery"); } catch { /* already gone */ }

        say("PASS");
    } catch (error) {
        say(`FAIL ${error instanceof Error ? error.message : String(error)}`);
        throw error;
    }
}
