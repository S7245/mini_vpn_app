# Spike: Rust core → 原生 reactive UI over FFI（去风险，可丢弃）

- 日期：2026-06-16
- 状态：进行中（spike）
- 关联：spec §7.1 选项 C（共享 Rust core + 薄原生 UI）的去风险输入

## 1. 为什么做这个 spike

spec §7.1 把"第二平台 GUI 栈复盘"定成数据驱动的 gate。选项 C（service/VM/逻辑
沉到共享 Rust core，每平台原生薄 UI）最有意思，但它最大的未知**不是**"能不能写
Rust"，而是：

> **用 FFI 把 Rust 的异步事件流（state/stats/log 连续推送）驱动原生 reactive UI 的
> 真实摩擦有多大** —— UniFFI 的 callback 接口 / 线程 / 取消 / 构建链路 / 类型映射。

这个 spike 只测这一条。**不押任何承诺，做完即可丢弃。** macOS 这程的 Swift
`MiniVPNCore`（ControlService 的 AsyncStream + ConnectionViewModel）是**参照 oracle**：
Rust 侧暴露的形状要对齐它，证明"同一套契约/状态机能从 Rust 经 FFI 喂给原生 UI"。

## 2. 明确不做（范围栅栏）

- 不接真实网络、不接 backend ②、不接真实 tunnel。只做 FFI 事件流→消费端的管道。
- 不动 `macos-app/`（已收口的 Swift 里程碑）。不动 `../mini_vpn`（core 仓）。
- 不做 Android/Windows——只在 macOS 上量 FFI 摩擦（结论可外推到其它 UniFFI 目标语言）。

## 3. 落地点

`spikes/rust-ffi-ui/`（本 worktree 内，独立 cargo crate）。

## 4. 形状（对齐 Swift oracle）

Rust 经 UniFFI 暴露一个 mirror ControlService 的接口：

- 枚举 `ControlEvent`：`State(ConnectionState)` / `Stats{up_bps,down_bps,up_bytes,down_bytes}`
  / `Log{level,message}` / `Error(String)`——对齐 Swift 的 `ControlEvent`。
- callback 接口 `EventObserver { fn on_event(ControlEvent) }`——Swift 侧实现，Rust 回调。
- 对象 `ControlService`：`connect()` / `disconnect()`，内部 1s ticker 推 stats（mock 行为
  与 Swift `MockControlService` 一致：connecting→connected→stats→log，然后每秒 stats）。

## 5. 阶段与验收

- **Phase 1（必须）—— FFI 事件流证明（CLI Swift）**
  - Rust 静态库 + UniFFI 生成 Swift 绑定；一个命令行 Swift 程序链接它，注册 observer，
    调 `connect()`，**实时收到** Rust ticker 推来的 state/stats/log 并打印。
  - 验收：终端看到 connecting→connected→log→每秒 stats；干净退出（disconnect 停 ticker）。
  - **产出：friction log**（构建/bindgen/链接步骤数、回调到达的线程、async/取消处理、
    类型映射的别扭处）——这是喂给 §7.1 的真实数据。
- **Phase 2（可选，仅当 Phase 1 干净）—— 绑到 SwiftUI**
  - 把 observer 回调桥到 `@MainActor @Published`，一个 SwiftUI 开关 + 实时 stats 标签。
  - 量额外摩擦：MainActor hop、xcodebuild 链接 staticlib/xcframework 的构建税。

## 6. 结论去向

friction log + 判断写回 spec §7.1 的输入清单（"AI 写原生 UI 速度 / FFI 摩擦"项），
作为 C vs A 复盘时的实测依据。spike 代码本身可删。
