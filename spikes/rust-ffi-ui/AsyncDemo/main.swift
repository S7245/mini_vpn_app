import Foundation

// THROWAWAY SPIKE (Phase 3): consume a tokio-backed async Rust core from Swift
// `await`. Proves the foreign-executor layer (UniFFI async + tokio runtime)
// works end to end: an awaited request/response (`ping`) and a tokio-driven
// event burst pushed over the callback (`streamTicks`).

final class Obs: EventObserver {
    func onEvent(event: ControlEvent) {
        print("[\(Thread.isMainThread ? "main" : "bg")] \(event)")
    }
}

let svc = ControlService(observer: Obs())
let sem = DispatchSemaphore(value: 0)

Task {
    print("== await ping() ==")
    let p = await svc.ping()
    print("ping -> \(p)")

    print("== await streamTicks(count: 3) (tokio task -> FFI callback) ==")
    await svc.streamTicks(count: 3)
    print("stream done")
    sem.signal()
}

sem.wait()
