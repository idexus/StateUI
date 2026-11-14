// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The chosen host's conformance marks made again in a checkout by the stateui tool (`repository/conformance`) -
// every family, or only those whose verdicts stand at another revision than
// lib/StateUI/StateUI.Conformance/revisions.txt says - and the control dictionary rendered again from them, each a
// phase of the run. A checkout's own work: an application's workspace holds no marks.

import { Host } from "./hosts";
import { ConformanceRequest, SuiteResult } from "./Tooling/protocol";

/** Which families a rebuild runs: every one, or those whose verdicts are stale. */
export type Rebuild = "all" | "changed";

/**
 * What the tool is asked to make `host`'s marks again with: every family or the stale ones, recorded - the documents
 * its last phase. `device` - an Android serial, a simulator's UDID - is where a UIKit or Android suite runs;
 * undefined where it needs one and was given none.
 */
export function conformanceRequest(host: Host, rebuild: Rebuild, device?: string): ConformanceRequest | undefined {
    if ((host === "uikit" || host === "android") && !device) {
        return undefined;
    }
    return {
        host, selection: rebuild === "changed" ? { changed: true } : { all: true }, record: true, ...(device ? { device } : {}),
    };
}

/** The phases of a run that failed, by name: none where it passed. */
export function failedPhases(result: SuiteResult): string[] {
    return result.phases.filter((each) => !each.passed).map((each) => each.name);
}
