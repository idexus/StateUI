// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The chosen host's conformance marks made again in a checkout by the stateui tool - every family, or only those whose
// verdicts stand at another revision than lib/StateUI/StateUI.Conformance/revisions.txt says - and the control dictionary
// rendered again from them. A checkout's own work: an application's workspace holds no marks.

import { Host } from "./hosts";
import { Step } from "./reinstall";

/** Which families a rebuild runs: every one, or those whose verdicts are stale. */
export type Rebuild = "all" | "changed";

/** A step of a rebuild: a command line, where it runs, and what its environment is handed. */
export interface RebuildStep extends Step {
    readonly env: Record<string, string>;
}

/**
 * The step that makes `host`'s marks again in `checkout` and renders the documents from them: `stateui repo
 * conformance run --record`, every family or the stale ones, through `tool` - the documents its last phase. `device` -
 * an Android serial, a simulator's UDID - is where a UIKit or Android suite runs; undefined where it needs one and was
 * given none.
 */
export function rebuildSteps(checkout: string, host: Host, rebuild: Rebuild, device?: string, tool = "stateui"): RebuildStep[] | undefined {
    if ((host === "uikit" || host === "android") && !device) {
        return undefined;
    }
    return [{
        command: tool, cwd: checkout, env: {},
        args: ["repo", "conformance", "run", "--host", host, rebuild === "changed" ? "--changed" : "--all", "--record",
            ...(device ? ["--device", device] : [])],
    }];
}
