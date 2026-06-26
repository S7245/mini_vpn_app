import Foundation
import os

/// Deterministic ① mock with **multi-subscriber broadcast**. `events()` may be
/// called by more than one consumer (the app wires a RootView into both a
/// WindowGroup and a MenuBarExtra, and SwiftUI may re-run `.onAppear`), so each
/// call gets its own stream and every emitted event fans out to all live
/// subscribers — matching how a real broadcasting transport behaves.
///
/// All mutable state lives behind an `OSAllocatedUnfairLock`, so attach is
/// SYNCHRONOUS (the continuation is registered before `events()` returns — no
/// pre-attach race, no buffering needed) and the ticker/`send` fan-out is
/// race-free. `onTermination` removes a subscriber when its stream ends (e.g.
/// the consuming pump Task is cancelled), and `deinit` finishes every remaining
/// subscriber.
public final class MockControlService: ControlService, @unchecked Sendable {
    private struct State {
        var subscribers: [UUID: AsyncStream<ControlEvent>.Continuation] = [:]
        var upBytes = 0
        var downBytes = 0
        var tickTask: Task<Void, Never>?
    }

    private let liveTicker: Bool
    private let state = OSAllocatedUnfairLock(initialState: State())

    public init(liveTicker: Bool = true) {
        self.liveTicker = liveTicker
    }

    public func events() -> AsyncStream<ControlEvent> {
        let id = UUID()
        return AsyncStream { cont in
            state.withLock { $0.subscribers[id] = cont }
            cont.onTermination = { [weak self] _ in
                self?.state.withLock { $0.subscribers[id] = nil }
            }
        }
    }

    public func send(_ command: ControlCommand) async throws {
        switch command {
        case .connect, .auto, .selectNode:
            emit(.state(.connecting))
            emit(.state(.connected))
            emitStatsTick()
            emit(.log(LogLine(level: .info, message: "tunnel established", ts: Date())))
            if liveTicker { startTicker() }
        case .disconnect:
            stopTicker()
            emit(.state(.disconnected))
            emit(.log(LogLine(level: .info, message: "disconnected", ts: Date())))
        }
    }

    /// Fan out to every live subscriber. Continuations are copied out under the
    /// lock, then yielded outside it (yield is non-blocking).
    private func emit(_ e: ControlEvent) {
        let conts = state.withLock { Array($0.subscribers.values) }
        for c in conts { c.yield(e) }
    }

    private func emitStatsTick() {
        let stats: TrafficStats = state.withLock {
            $0.upBytes += 64_000
            $0.downBytes += 480_000
            return TrafficStats(upBps: 128_000, downBps: 940_000, upBytes: $0.upBytes, downBytes: $0.downBytes)
        }
        emit(.stats(stats))
    }

    private func startTicker() {
        let task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                self.emitStatsTick()
            }
        }
        let old = state.withLock { s -> Task<Void, Never>? in
            let prev = s.tickTask
            s.tickTask = task
            return prev
        }
        old?.cancel()
    }

    private func stopTicker() {
        let old = state.withLock { s -> Task<Void, Never>? in
            let prev = s.tickTask
            s.tickTask = nil
            return prev
        }
        old?.cancel()
    }

    deinit {
        state.withLock { s in
            s.tickTask?.cancel()
            for c in s.subscribers.values { c.finish() }
        }
    }
}
