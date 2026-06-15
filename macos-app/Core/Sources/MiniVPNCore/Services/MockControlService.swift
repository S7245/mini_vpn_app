import Foundation

/// Deterministic ① mock, implemented as an `actor` so all mutable state
/// (`continuation`, byte counters, ticker) is serialized — no data race even
/// with `liveTicker` on, where the ticker task and `send` run concurrently.
///
/// Timing: `events()` is `nonisolated` and constructs the stream synchronously,
/// but attaching the continuation hops onto the actor asynchronously. To make
/// "events() then send()" reliable REGARDLESS of which lands on the actor
/// first, events emitted before a continuation is attached are buffered in
/// `pending` and flushed on attach. The AsyncStream's own unbounded buffer then
/// retains them until the consumer iterates. `finish()` is called on the
/// continuation in `deinit` so the stream terminates (no leaked pump task).
public actor MockControlService: ControlService {
    private let liveTicker: Bool
    private var continuation: AsyncStream<ControlEvent>.Continuation?
    private var pending: [ControlEvent] = []
    private var upBytes = 0
    private var downBytes = 0
    private var tickTask: Task<Void, Never>?

    public init(liveTicker: Bool = true) {
        self.liveTicker = liveTicker
    }

    public nonisolated func events() -> AsyncStream<ControlEvent> {
        AsyncStream { cont in
            Task { await self.attach(cont) }
        }
    }

    private func attach(_ cont: AsyncStream<ControlEvent>.Continuation) {
        continuation = cont
        for e in pending { cont.yield(e) }
        pending.removeAll()
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

    /// Yields if a continuation is attached, otherwise buffers until attach.
    private func emit(_ e: ControlEvent) {
        if let continuation { continuation.yield(e) } else { pending.append(e) }
    }

    private func emitStatsTick() {
        upBytes += 64_000
        downBytes += 480_000
        emit(.stats(TrafficStats(upBps: 128_000, downBps: 940_000, upBytes: upBytes, downBytes: downBytes)))
    }

    private func startTicker() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self else { return }
                await self.emitStatsTick()
            }
        }
    }

    private func stopTicker() { tickTask?.cancel(); tickTask = nil }

    deinit {
        tickTask?.cancel()
        continuation?.finish()
    }
}
