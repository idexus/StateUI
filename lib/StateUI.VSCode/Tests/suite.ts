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
import { findApplications } from "../Sources/applications";
import { StateUIDebugConfigurationProvider } from "../Sources/debug";
import { findSuites } from "../Sources/tests";
import { MauiDebugger } from "../Sources/hosts";
import { StateUIApi } from "../Sources/extension";

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
        const head = path.join(gallery, "Platforms", "AppKit", "Host", "GalleryControls.swift");

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
        const resolveAs = async (chosen: MauiDebugger, platform: NodeJS.Platform, configuration = "debug") => {
            const ran: string[] = [];
            const attached: string[] = [];
            const provider = new StateUIDebugConfigurationProvider({
                host: () => "maui", application: async () => gallery_, debugger: () => chosen, platform,
                run: async (task) => {
                    const shell = task.execution as vscode.ShellExecution;
                    ran.push([shell.command, ...(shell.args ?? [])].map(String).join(" "));
                    return 0;
                },
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
                resolved?.type === "maui" && resolved.targetFramework === "net10.0-maccatalyst"
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

        // 5. The suites, found for each host the way test-native.sh runs them.
        const appkitSuites = findSuites(root.uri.fsPath, "appkit").map((each) => each.label);
        const mauiSuites = findSuites(root.uri.fsPath, "maui").map((each) => each.label);
        say(`appkit suites: ${appkitSuites.join(", ")}`);
        say(`maui suites: ${mauiSuites.join(", ")}`);
        check("appkit runs the core, StateUI.AppKit and the Gallery, and no C#",
            appkitSuites.includes("StateUI") && appkitSuites.includes("lib/StateUI.AppKit")
            && appkitSuites.includes("apps/Gallery") && !mauiSuites.includes("lib/StateUI.AppKit")
            && !appkitSuites.some((each) => each.endsWith("Tests")));
        check("maui runs the core, the Gallery and the C# suite, and not StateUI.AppKit",
            mauiSuites.includes("StateUI") && mauiSuites.includes("apps/Gallery")
            && mauiSuites.includes("lib/StateUI.Maui/Tests") && !mauiSuites.includes("lib/StateUI.AppKit"));

        // 6. StateUI: Debug on AppKit runs the REMEMBERED application - no
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


        // 7. LIVE: Swift · Mac Catalyst - run-app.sh builds and starts the
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
