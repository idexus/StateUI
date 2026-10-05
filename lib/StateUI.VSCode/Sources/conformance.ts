// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The chosen host's conformance marks made again in a checkout - every family, or only those whose verdicts stand at
// another revision than lib/StateUI/StateUI.Conformance/revisions.txt says - and the control dictionary rendered again from
// them. A checkout's own work: an application's workspace holds no marks.

import * as path from "path";
import { Host } from "./hosts";
import { Step } from "./reinstall";

/** Which families a rebuild runs: every one, or those whose verdicts are stale. */
export type Rebuild = "all" | "changed";

/** A step of a rebuild: a command line, where it runs, and what its environment is handed. */
export interface RebuildStep extends Step {
    readonly env: Record<string, string>;
}

/**
 * The steps that make `host`'s marks again in `checkout` and render the documents from them: the host's conformance
 * families run writing their verdicts, then the dictionary's renderer. `device` - an Android serial, a simulator's
 * UDID - is where the host's suite runs on one. Undefined where the host cannot: a device the suite needs and was not
 * given, Android asked for the changed families, as its device reads no repository, or the Web, which has no
 * conformance driver yet.
 */
export function rebuildSteps(checkout: string, host: Host, rebuild: Rebuild, device?: string): RebuildStep[] | undefined {
    const scripts = path.join(checkout, ".scripts");
    const writing: Record<string, string> = { STATEUI_UPDATE_EXPORTS: "1" };
    const env = rebuild === "changed" ? { ...writing, STATEUI_STALE_ONLY: "1" } : writing;
    let run: RebuildStep;
    switch (host) {
    case "winui":
        run = {
            command: "powershell",
            args: ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", path.join(scripts, "WinUI", "test-winui.ps1"),
                rebuild === "changed" ? "-Stale" : "-Conformance"],
            cwd: checkout, env: writing,
        };
        break;
    case "appkit":
        run = { command: "bash", args: [path.join(scripts, "AppKit", "test-appkit.sh"), "--filter", "AppKitConformanceTests"], cwd: checkout, env };
        break;
    case "gtk":
        run = { command: "bash", args: [path.join(scripts, "GTK", "test-gtk.sh"), "--filter", "GTKConformanceTests"], cwd: checkout, env };
        break;
    case "uikit":
        if (!device) {
            return undefined;
        }
        run = {
            command: "bash", args: [path.join(scripts, "UIKit", "test-uikit.sh"), device], cwd: checkout,
            env: { ...env, STATEUI_FILTER: "UIKitConformanceTests" },
        };
        break;
    case "web":
        return undefined;
    case "android":
        if (rebuild === "changed" || !device) {
            return undefined;
        }
        run = { command: "bash", args: [path.join(scripts, "Android", "test-android.sh"), device], cwd: checkout, env: writing };
        break;
    }
    const render: RebuildStep = {
        command: "swift", args: ["test", "--filter", "ControlDictionaryTests"], cwd: checkout, env: { STATEUI_UPDATE_DOCS: "1" },
    };
    return [run, render];
}
