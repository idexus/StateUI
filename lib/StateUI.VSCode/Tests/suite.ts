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
import { StateUIDebugConfigurationProvider } from "../Sources/debug";
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

        // 4. A MAUI launch becomes the MAUI extension's, naming the chosen
        //    application's project and no device - that extension's picker's.
        const memory = new Map<string, unknown>();
        const state = {
            keys: () => [...memory.keys()],
            get: <T>(key: string, fallback?: T) => (memory.has(key) ? memory.get(key) as T : fallback),
            update: async (key: string, value: unknown) => { memory.set(key, value); },
        } as vscode.Memento;
        const maui = new StateUIDebugConfigurationProvider({ host: () => "maui", state });
        const release = await maui.resolveDebugConfiguration(root,
            { name: "StateUI: Release", type: "stateui", request: "launch", configuration: "release", application: "Gallery" });
        check("maui release resolves to the maui type, in Release, on Gallery's project, with no device",
            release?.type === "maui" && release.configuration === "Release"
            && String(release.project).endsWith("/apps/Gallery/Platforms/Maui/Gallery.csproj")
            && release.device === undefined);

        // 5. StateUI: Debug on AppKit builds HelloWorld and runs it under lldb-dap.
        await api.selectHost("appkit");
        const session = new Promise<vscode.DebugSession>((resolve) => {
            const listener = vscode.debug.onDidStartDebugSession((each) => {
                if (each.type === "lldb-dap") {
                    listener.dispose();
                    resolve(each);
                }
            });
        });
        check("StateUI: Debug starts", await vscode.debug.startDebugging(root,
            { name: "StateUI: Debug", type: "stateui", request: "launch", configuration: "debug", application: "HelloWorld" }));
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
