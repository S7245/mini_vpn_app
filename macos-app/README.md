# macos-app

The macOS SwiftUI client. Runs entirely against `contracts/` mocks for now;
the service layer swaps mock → real backend ② / local-control ① with no UI change.

## Layout
- `Core/` — Swift Package: models, services (`BackendService`/`ControlService`
  + mocks), view models, SwiftUI views. All logic is tested with `swift test`.
- `App/` — thin Xcode app shell (generated from `project.yml` via XcodeGen):
  `@main`, menu bar, root window. Wires the MOCK services in `MiniVPNApp.swift`.

## Test the logic (no Xcode project needed)
```bash
cd macos-app/Core && swift test
```

## Build / run the app
```bash
cd macos-app
./scripts/sync-mocks.sh                  # refresh bundled fixtures from contracts/
cd App && xcodegen generate && open MiniVPN.xcodeproj
```

## Keeping mocks in sync
`scripts/sync-mocks.sh` copies `contracts/mock/*.json` into the Core bundle.
`contracts/` is the single source of truth — never hand-edit the copies.

When the real backend lands, replace `MockBackendService()` / `MockControlService()`
in `App/Sources/MiniVPNApp.swift` with the real implementations.
