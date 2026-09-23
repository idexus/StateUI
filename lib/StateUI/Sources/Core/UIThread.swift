// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The one thread everything here runs on: the host's UI thread, whose actor is
// Swift's `MainActor` on every platform.
//
// This library has no thread and no run loop of its own. Everything it does
// happens inside a call the host makes - a render, an event, an act reporting
// back - on the host's UI thread. A handler runs on `MainActor` and may
// SUSPEND in the middle of that; it resumes on MainActor's executor.
//
// ON APPLE that executor is the main queue, which the platform's own event
// loop drains on the thread it draws on. Nothing here replaces it.
//
// ELSEWHERE - Android, Windows, Linux - MainActor's executor would be
// libdispatch's main queue too, and nothing drains it: the UI thread is
// turning Android's Looper, the WinUI message pump or GTK's main loop, and a
// handler would suspend at its first `await` and never wake. So there
// MainActor's executor is `UIThreadExecutor`, installed through Swift's
// executor factory before the first task: it queues each job, and the host
// empties the queue on its UI thread through `stateui_run_jobs`. The factory
// is `@_spi(ExperimentalCustomExecutors)`; its shape is that of the one Swift
// release StateUI builds with.
//
// A HANDLER STARTS WHERE ITS EVENT ARRIVES. `Task.immediate` runs it on the UI
// thread up to its first suspension, before the call that raised the event
// returns - so a handler with no `await` in it finishes inside its event, and
// the host renders what it wrote in the same turn. See `Renderer.start`.
//
// WHY THE HOST IS NOT CALLED BACK:
// Handing each job to a host function pointer is a trap. `resume()` produces
// its job on a cooperative-pool thread - measured, and unavoidable - so such a
// callback enters the host from a thread its runtime has never seen. A
// foreign-language host's runtime attaches such a thread on the way in, and on
// Android, with a debugger attached, that attach can deadlock the UI thread:
// the app freezes on the first `await` in a handler and stops receiving
// touches. Without a debugger the same build is fine, which is the worst way
// to find out.
//
// So nothing here calls out. The host asks, through `stateui_run_jobs`.
//
// HOW THE HOST KNOWS WHEN TO ASK:
// A job can land when no act is in flight at all: Task.sleep coming due, a
// task an author started finishing, an AsyncStream yielding. So the host parks
// a thread of its OWN inside `stateui_wait_work`, and `enqueue` signals it - as
// do a state write and `Renderer.send` (`poke`), for the work a task on the
// pool leaves with no job to announce it. The thread wakes, posts one turn
// onto the UI thread the toolkit's own way - which is thread-safe on every
// platform - and parks again. On Apple the doorbell rings for that work alone;
// MainActor's jobs are the main queue's.
//
// That is what makes `Task.sleep` and every other plain Swift await legal in a
// handler: what a handler awaits does not have to be a host act.
//
// The attach trap above shapes that thread too: the HOST creates it, so its
// runtime has always known it, and it only ever calls the host's own code
// (the post onto the UI thread). Nothing here calls out; the host asks,
// through a thread whose whole job is to ask the moment there is something to
// ask about.

import Dispatch
#if !canImport(Darwin)
@_spi(ExperimentalCustomExecutors) import _Concurrency
#endif

/// The executor whose jobs the host runs on its UI thread - MainActor's own on
/// every platform but Apple's - and the doorbell that tells the host to ask.
///
/// `@unchecked Sendable` for the reason everything else here is: what makes it
/// safe is external - the host empties the queue from one thread - and cannot be
/// expressed structurally. The queue ITSELF is guarded, because that is the one
/// thing here that really is touched from more than one thread.
final class UIThreadExecutor: SerialExecutor, @unchecked Sendable {
    /// The one executor. There is one host, and one thread it draws on.
    static let shared = UIThreadExecutor()

    /// Makes this MainActor's executor where the platform's main queue is
    /// drained by nobody - every platform but Apple's. Once, and before the
    /// first task: MainActor's executor is chosen when it is first used.
    static func install() {
        _ = installed
    }

    private static let installed: Void = {
        #if !canImport(Darwin)
        _createExecutors(factory: UIThreadExecutorFactory.self)
        #endif
    }()

    /// Guards the queue, the doorbell's flag and the two below, and nothing
    /// else.
    private let guarded = Lock()

    /// Jobs waiting for the host to run them.
    private var pending: [UnownedJob] = []

    /// What the host's parked thread waits on - see the file header. Signalled
    /// by `enqueue`, at most once per park, which is what `wakeArmed` is for:
    /// a semaphore that was signalled a thousand times would wake the thread a
    /// thousand times for the one drain the first wake already caused.
    private let wake = DispatchSemaphore(value: 0)

    /// Whether a wake has been signalled that the parked thread has not
    /// collected yet.
    private var wakeArmed = false

    /// Whether a drain is posted to the platform's main queue and has not run.
    ///
    /// Where something turns that queue - a test's run loop, a command line's
    /// `dispatchMain` - it drains this queue as well, so MainActor works there
    /// too. Where nothing turns it, the one post waits for ever and no second
    /// is made: the host's drain is what runs the jobs.
    private var mainQueueAsked = false

    /// Whether a drain is running. A second drain entered meanwhile - on
    /// another thread, or from inside a job - returns at once: two threads must
    /// never run MainActor's jobs side by side, and the running drain takes
    /// whatever lands while it runs.
    private var draining = false

    /// Whether `run()` has been told to return.
    private var stopped = false

    /// Takes a job. Runs nothing here - but wakes the host.
    ///
    /// Called on whatever thread Swift's runtime happens to be holding - the UI
    /// thread when a handler starts, a cooperative-pool thread when one resumes.
    /// Neither is allowed to run the job: the first would be right by luck, and
    /// the second would run MainActor's code beside the host's render.
    ///
    /// The signal and the post happen outside the lock; they only wake a
    /// thread, and holding a lock across even that is how lock orders are born.
    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)

        let (signal, post): (Bool, Bool) = guarded.withLock {
            pending.append(job)

            let post = !mainQueueAsked
            mainQueueAsked = true

            guard !wakeArmed else { return (false, post) }
            wakeArmed = true
            return (true, post)
        }

        if signal { wake.signal() }

        if post {
            DispatchQueue.main.async {
                UIThreadExecutor.shared.drainFromTheMainQueue()
            }
        }
    }

    /// Wakes the host's parked thread with nothing queued HERE - for work this
    /// queue cannot see.
    ///
    /// An ACT is that work: an act queued from a plain `Task` runs on the
    /// pool and lands no job on this executor, so without this wake the host
    /// would not hear of the act until some other event made it look - the
    /// return half of a press animation sitting queued and the card staying
    /// pressed, on Android for ever. `Renderer.send` calls this after queueing;
    /// the same armed flag coalesces it with `enqueue`'s wake.
    func poke() {
        let signal: Bool = guarded.withLock {
            guard !wakeArmed else { return false }
            wakeArmed = true
            return true
        }

        if signal { wake.signal() }
    }

    /// Parks the calling thread until a job lands, and returns how many are
    /// waiting. What `stateui_wait_work` runs - see Bridge/Exports.swift for
    /// who calls it and why that thread is the host's to give.
    func waitForWork() -> Int {
        wake.wait()

        return guarded.withLock {
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
        let entered: Bool = guarded.withLock {
            guard !draining else { return false }
            draining = true
            return true
        }

        guard entered else { return 0 }

        var ran = 0

        for _ in 0..<64 {
            let taken: [UnownedJob] = guarded.withLock {
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

        guarded.withLock { draining = false }
        return ran
    }

    /// The drain the platform's main queue runs, where something turns it.
    private func drainFromTheMainQueue() {
        guarded.withLock { mainQueueAsked = false }
        drain()
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
    /// tasks rather than a host act. What waits on it is a test, beside
    /// `resumesPending`, for a queue gone quiet: a host is woken by each job
    /// as it lands.
    var pendingCount: Int {
        guarded.withLock { pending.count }
    }

    /// Runs the UI thread's loop on the calling thread until `stop()`: waits for
    /// a job and drains. What an `async main` asks of MainActor's executor; a
    /// host drains through `stateui_run_jobs` instead.
    func runTheLoop() {
        while !guarded.withLock({ stopped }) {
            _ = waitForWork()
            drain()
        }

        guarded.withLock { stopped = false }
    }

    /// Makes `runTheLoop()` return after the drain it is in.
    func stopTheLoop() {
        guarded.withLock { stopped = true }
        poke()
    }
}

#if !canImport(Darwin)
extension UIThreadExecutor: MainExecutor {
    func run() throws {
        runTheLoop()
    }

    func stop() {
        stopTheLoop()
    }
}

/// MainActor's executor where nothing drains the platform's main queue, and
/// the platform's own for every other task.
private struct UIThreadExecutorFactory: ExecutorFactory {
    static var mainExecutor: any MainExecutor { UIThreadExecutor.shared }
    static var defaultExecutor: any TaskExecutor { PlatformExecutorFactory.defaultExecutor }
}
#endif

/// Runs whatever the Swift side has waiting, on the caller's thread.
///
/// The host calls this at the start of every turn - the one its doorbell posts
/// when a job lands, and the one after an event. It is safe to call at
/// any time and returns 0 when there is nothing to do - which on Apple, where
/// MainActor's jobs are the main queue's, is almost always.
///
/// Available to a test standing in for a host, which is the only other caller.
@discardableResult
func stateUIRunJobs() -> Int {
    UIThreadExecutor.shared.drain()
}
