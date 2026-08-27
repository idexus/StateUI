// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The one thread everything here runs on, expressed to the compiler.
//
// This library has no thread and no run loop of its own. Everything it does
// happens inside a call the C# host makes - a render, an event, a command
// reporting back - on the thread MAUI draws on. A handler may SUSPEND in the
// middle of that, and Swift's runtime has an opinion about where it resumes.
//
// Left alone, that opinion is wrong for us. Measured: `continuation.resume()`
// does not continue the handler where it stands. It schedules the rest of it,
// and the scheduler hands it to a thread from the cooperative pool - so the
// state writes after an `await` would land next to a C# render that assumes it
// is alone. Nothing would crash reliably, which is the worst kind of wrong.
//
// So the executor is ours, and it runs NOTHING by itself. A job is put in a
// queue, and the queue is emptied only when the host calls in - which is exactly
// the rule the rest of the library already lives by.
//
// WHY NOT @MainActor:
// On Apple it would work - MainActor's executor is the main queue and UIKit
// drains it. On Android and Windows MainActor is libdispatch's main queue, which
// nothing drains in a MAUI app: the main thread is turning Android's Looper or
// the WinUI message pump instead. A handler would suspend at its first `await`
// and never wake up, silently, on two platforms out of four. Replacing
// MainActor's own executor exists only behind an experimental SPI
// (`@_spi(ExperimentalCustomExecutors)`, from Swift 6.3) that any toolchain may
// change and the floor Apple runtimes do not carry, so nothing here leans on
// it. Hence a global actor of this library's own, whose jobs the host runs.
//
// WHY THE HOST IS NOT CALLED BACK:
// Handing each job to a C# function pointer works everywhere but Android, and
// there it is a trap. `resume()` produces its job on a cooperative-pool thread
// - measured, and unavoidable: resuming from inside a job on this very executor
// does not change it - so such a callback enters managed code from a thread the
// .NET runtime has never seen. Mono attaches such a thread on the way in, and
// with a debugger attached that attach deadlocks the UI thread: the app freezes
// on the first `await` in a handler and Android stops delivering touches to it.
// Without a debugger the same build is fine, which is the worst way to find out.
//
// So nothing here calls out. The host asks, through `stateui_run_jobs`.
//
// THE RULE, in one sentence: this side empties the queue in the one place it
// fills the queue synchronously - `Renderer.start`, which is what keeps a
// handler with no `await` in it finishing inside the event that raised it.
// Everything else is asked for, because everything else arrives LATER than the
// call that caused it. Draining anywhere else finds nothing and reads as though
// it might, which is exactly what the host's retry exists to deny.
//
// HOW THE HOST KNOWS WHEN TO ASK:
// For a job produced by a host command's completion, the host was there - it
// reported the completion, so it asks right after (and keeps asking, on a
// clock). But a job can land when no command is in flight at all: Task.sleep
// coming due, a Task an author started finishing, an AsyncStream yielding. For
// those the host parks a MANAGED thread inside `stateui_wait_work`, and
// `enqueue` signals it - as does `Renderer.send` (`poke`), for the act a
// plain `Task` queues from the pool with no job to announce it. The thread
// wakes, posts one drain onto the UI thread through the host's own
// dispatcher - which is thread-safe on every platform - and parks again.
//
// That is what makes `Task.sleep` and every other plain Swift await legal in a
// handler: what a handler awaits does not have to be a host command.
//
// The Mono trap above shapes that thread too: it is CREATED BY C#, so the
// runtime has always known it, and it only ever calls MANAGED code (its own
// dispatcher). Nothing here calls out; the host asks, through a thread whose
// whole job is to ask the moment there is something to ask about.

import Dispatch

/// The thread MAUI draws on, as an isolation domain. MAUI: MainThread.
///
/// Every event handler runs here, and so does everything a handler awaits. It is
/// the same thread the renderer works on, which is what lets a handler read and
/// write `State` without any locking.
///
/// Worth naming explicitly only when writing an async function of your own that
/// a handler calls:
///
///     @MainThread
///     func loadTheNextPage() async throws {
///         try await Dialogs.displayAlert("Loaded", message: "the next page")
///     }
///
/// A handler closure is already isolated to it, so an ordinary
/// `.onClicked { … }` needs nothing. A plain `async func` of your own is the
/// case that does: written nonisolated it resumes on Swift's cooperative pool,
/// so either name this actor on it, as above, or turn on
/// `NonisolatedNonsendingByDefault` in the module that holds it - which is what
/// every package here does, and what the generated app's manifest carries.
///
/// NOT the same as Swift's `@MainActor`, even on Apple platforms where both mean
/// the same thread: `@MainActor` code still has to be reached with
/// `await MainActor.run { … }`. This library never needs it, having no UIKit of
/// its own to call.
@globalActor
public actor MainThread {
    /// The instance the attribute refers to. Required of every global actor.
    public static let shared = MainThread()

    /// Runs this actor's work when the host asks, rather than whenever Swift's
    /// scheduler feels like it - see the note at the top of this file.
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        MainThreadExecutor.shared.asUnownedSerialExecutor()
    }
}

/// Holds the jobs of `@MainThread` until the host runs them.
///
/// `@unchecked Sendable` for the reason everything else here is: what makes it
/// safe is external - the host empties the queue from one thread - and cannot be
/// expressed structurally. The queue ITSELF is guarded, because that is the one
/// thing here that really is touched from more than one thread.
final class MainThreadExecutor: SerialExecutor, @unchecked Sendable {
    /// The one executor. There is one host, and one thread it draws on.
    static let shared = MainThreadExecutor()

    /// Guards `pending` and `wakeArmed`, and nothing else.
    ///
    /// A serial `DispatchQueue` used as a mutex rather than Foundation's
    /// `NSLock`: libdispatch is on every platform this targets and Foundation on
    /// Windows links ICU, which is the one dependency this library cannot take.
    /// `Synchronization.Mutex` would be the modern answer and is iOS 18, above
    /// this floor.
    ///
    /// NOT the main queue, and nothing here waits on one: this is a private
    /// queue, entered synchronously, held for an array append.
    private let guarded = DispatchQueue(label: "StateUI.MainThread.jobs")

    /// Jobs waiting for the host to run them.
    private var pending: [UnownedJob] = []

    /// What the host's parked thread waits on - see the file header. Signalled
    /// by `enqueue`, at most once per park, which is what `wakeArmed` is for:
    /// a semaphore that was signalled a thousand times would wake the thread a
    /// thousand times for the one drain the first wake already caused.
    private let wake = DispatchSemaphore(value: 0)

    /// Whether a wake has been signalled that the parked thread has not
    /// collected yet. Behind `guarded`.
    private var wakeArmed = false

    /// Takes a job. Runs nothing here - but wakes the host.
    ///
    /// Called on whatever thread Swift's runtime happens to be holding - the UI
    /// thread when a handler starts, a cooperative-pool thread when one resumes.
    /// Neither is allowed to run the job: the first would be right by luck, and
    /// the second would be the bug this whole file exists to prevent.
    ///
    /// The wake is what lets the job be one NO command produced - a
    /// `Task.sleep` coming due, a task an author started finishing - and still
    /// run promptly. The signal happens outside the lock; it only wakes a
    /// thread, and holding an unrelated lock across even that is how lock
    /// orders are born.
    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)

        let signal: Bool = guarded.sync {
            pending.append(job)

            guard !wakeArmed else { return false }
            wakeArmed = true
            return true
        }

        if signal { wake.signal() }
    }

    /// Wakes the host's parked thread with nothing queued HERE - for work this
    /// queue cannot see.
    ///
    /// A COMMAND is that work: an act queued from a plain `Task` runs on the
    /// pool and lands no job on this executor, so without this wake the host
    /// would not hear of the act until some other event made it look - the
    /// return half of a press animation sitting queued and the card staying
    /// pressed, on Android for ever. `Renderer.send` calls this after queueing;
    /// the same armed flag coalesces it with `enqueue`'s wake.
    func poke() {
        let signal: Bool = guarded.sync {
            guard !wakeArmed else { return false }
            wakeArmed = true
            return true
        }

        if signal { wake.signal() }
    }

    /// Parks the calling thread until a job lands, and returns how many are
    /// waiting. The far side of `stateui_wait_work` - see Bridge/Exports.swift
    /// for who calls it and why that thread is the host's to give.
    func waitForWork() -> Int {
        wake.wait()

        return guarded.sync {
            wakeArmed = false
            return pending.count
        }
    }

    /// Runs every job waiting, on the calling thread, and returns how many ran.
    ///
    /// Loops, because a job can queue another: a handler that awaits twice comes
    /// back through here each time. Bounded, so that a job which re-queues itself
    /// for ever cannot take the UI thread with it - the count says what happened
    /// and the host asks again.
    @discardableResult
    func drain() -> Int {
        var ran = 0

        for _ in 0..<64 {
            let taken: [UnownedJob] = guarded.sync {
                let taken = pending
                pending.removeAll(keepingCapacity: true)
                return taken
            }

            if taken.isEmpty { break }

            // Outside the lock on purpose: a job that queues another would
            // otherwise deadlock on it.
            for job in taken {
                job.runSynchronously(on: asUnownedSerialExecutor())
                ran += 1
            }
        }

        return ran
    }

    /// This executor, in the form the runtime stores.
    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }

    /// How many jobs are waiting, without running any.
    ///
    /// The half of the queue's state `resumesPending` cannot see: a handler
    /// suspended on `async let` children resumes through a job that no
    /// completion accounting covers, because what it awaited was its own child
    /// tasks rather than a host command. The host polls this beside
    /// `stateui_resumes_pending`, so a job that lands after the counters read
    /// zero is still collected. See `StateUISession.DrainWhenTheResumeArrives`.
    var pendingCount: Int {
        guarded.sync { pending.count }
    }
}

/// Runs whatever the Swift side has waiting, on the caller's thread.
///
/// The host calls this after reporting that an act has finished, because that is
/// when a suspended handler has something to come back to. It is safe to call at
/// any time and returns 0 when there is nothing to do.
///
/// Available to a test standing in for a host, which is the only other caller.
@discardableResult
func stateUIRunJobs() -> Int {
    MainThreadExecutor.shared.drain()
}
