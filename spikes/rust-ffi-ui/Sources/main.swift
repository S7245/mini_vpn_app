// THROWAWAY SPIKE — Swift CLI consumer of the Rust minivpn_ffi event stream.
//
// Implements the generated `EventObserver` protocol, registers it with the
// Rust `ControlService`, calls connect(), prints each pushed event WITH the
// thread it arrived on (main vs background — a key FFI finding), waits ~3.5s
// to collect ticker stats, then disconnect()s and prints "done".

import Foundation

final class PrintingObserver: EventObserver, @unchecked Sendable {
    func onEvent(event: ControlEvent) {
        let where_ = Thread.isMainThread ? "MAIN" : "bg"
        switch event {
        case let .state(state):
            print("[\(where_)] state: \(state)")
        case let .stats(upBps, downBps, upBytes, downBytes):
            print("[\(where_)] stats: up_bps=\(upBps) down_bps=\(downBps) up_bytes=\(upBytes) down_bytes=\(downBytes)")
        case let .log(level, message):
            print("[\(where_)] log(\(level)): \(message)")
        case let .error(detail):
            print("[\(where_)] error: \(detail)")
        }
    }
}

let observer = PrintingObserver()
let service = ControlService(observer: observer)

print("== connect ==")
service.connect()

Thread.sleep(forTimeInterval: 3.5)

print("== disconnect ==")
service.disconnect()

Thread.sleep(forTimeInterval: 0.3)
print("done")
