// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Runs a task and waits for it - how the extension builds a head and runs a
// suite - or starts one that runs until stopped, as an Android head's log does,
// with the output where a task's always is: the terminal.

import * as fs from "fs";
import * as vscode from "vscode";

/**
 * Runs `task` and answers its exit code. The listener is in place before the
 * task starts, so one that ends at once is not missed.
 */
export function runTask(task: vscode.Task): Promise<number | undefined> {
    return new Promise((resolve, reject) => {
        let started: vscode.TaskExecution | undefined;
        let ended = false;

        const listener = vscode.tasks.onDidEndTaskProcess((event) => {
            if (started ? event.execution === started : event.execution.task.definition === task.definition) {
                listener.dispose();
                ended = true;
                resolve(event.exitCode);
            }
        });

        vscode.tasks.executeTask(task).then(
            (execution) => { started = execution; },
            (error) => { listener.dispose(); if (!ended) { reject(error); } });
    });
}

/**
 * Starts `task`, which runs until it is stopped - a head followed by its log -
 * and answers once it has started. A StateUI task for the same application on
 * the same device still running is stopped first and waited for, so starting
 * again is a restart rather than a second run beside the first.
 */
export async function startTask(task: vscode.Task): Promise<void> {
    const { application, device } = task.definition;
    const replaced = vscode.tasks.taskExecutions.filter((each) => device !== undefined && each.task.definition.type === "stateui"
        && each.task.definition.application === application && each.task.definition.device === device);

    await Promise.all(replaced.map((execution) => new Promise<void>((resolve) => {
        const listener = vscode.tasks.onDidEndTask((event) => {
            if (event.execution === execution) {
                listener.dispose();
                resolve();
            }
        });
        execution.terminate();
    })));

    await vscode.tasks.executeTask(task);
}

/**
 * Waits, while `task` runs, for `file` to appear - what a task that goes on
 * running writes once it is ready - and answers whether it did: false once the
 * task has ended without it, or after `limit` milliseconds.
 */
export function readyWhen(file: string, task: vscode.Task, limit = 15 * 60_000): Promise<boolean> {
    return new Promise((resolve) => {
        const since = Date.now();
        const finish = (ready: boolean): void => {
            clearInterval(timer);
            listener.dispose();
            resolve(ready);
        };
        const listener = vscode.tasks.onDidEndTask((event) => {
            if (event.execution.task.definition === task.definition) {
                finish(fs.existsSync(file));
            }
        });
        const timer = setInterval(() => {
            if (fs.existsSync(file)) {
                finish(true);
            } else if (Date.now() - since > limit) {
                finish(false);
            }
        }, 500);
    });
}
