# ADR: 多端 GUI 栈选 C（共享 Rust core 经 FFI + 每平台薄原生 UI）

- 日期：2026-06-19
- 状态：**已接受（Accepted）**
- 决策者：Sam（单人主力维护）
- 关联：本决定收口 [设计 §7.1](../specs/2026-06-12-frontend-contract-first-macos-design.md) 的"第二平台 GUI 栈复盘" gate；
  替代 §2.1 当初"延后全局栈决策"的占位。
- 证据：`spikes/rust-ffi-ui/FINDINGS.md`（FFI 4 阶段）、`spikes/macos-netext/TAX.md`（网络扩展税）。

## 背景

§2.1 当初在无数据时只权衡 A（原生逐平台）vs B（Flutter），并**故意延后**全局栈决策。
§7.1 把它钉成 event-based gate：第二平台定为非 Apple 平台时触发，用实测输入替换推测。

- **触发**（2026-06-16）：第二平台定为 **Android**。
- **证据收集**（2026-06-16 ~ 06-19）：做了 5 段去风险 spike。

## 决定

**采纳 C：可移植层（数据面 + 控制/业务逻辑 + ① local-control 语义）沉到共享 Rust core，
经 UniFFI 暴露；每平台写薄的原生 UI（Apple SwiftUI / Android Compose）消费它。**

B 排除；A 作为"已知次优 fallback"保留。

## 理由（基于实测，非推测）

1. **FFI 摩擦已退清**（`rust-ffi-ui` Phase 1–4c）：UniFFI 生成 idiomatic Swift + Kotlin；
   sync 回调流 + tokio/async（`await`）都通；Apple 侧 xcframework+SwiftUI 与 Android 侧
   arm64 `.so`+Kotlin **均 on-device 实跑**（macOS app、Android 模拟器），行为与契约 oracle 一致。
   唯一强制成本是一次 MainActor / `Dispatchers.Main` hop（样板、低风险）。
2. **决定性事实**（`macos-netext/TAX.md`）：mini_vpn 的**数据面本体已是 Rust**，所以每平台的
   网络扩展（NEPacketTunnelProvider / VpnService）**无论 A/B/C 都必须在进程内 FFI-host 那个
   Rust 核**。FFI 边界是 VPN 形态的既定前提，不是 C 的额外成本。这把 A vs C 压扁：两者都付薄的
   NE 原生胶水 + 都 FFI 数据面核，**唯一差别是控制/业务逻辑 A 每平台重写、C 沿同一道边界写一次**
   ——边际≈0、纯收益（消 N 路漂移、契约一处守）。
3. **B 出局**：VPN 的网络扩展每平台仍须原生，Flutter 只省简单 GUI 还加一道桥 + 第 4 语言。
4. **单人维护**：C 把"逻辑测一处"，把 N 路 GUI 之外最易漂移的控制逻辑收敛到一份。

## 后果

**正向**
- 控制/业务逻辑写一次（Rust），各端薄壳消费；契约一致性一处守。
- 保留原生 UI 贴合度（不像 B）。
- 与既有 Rust 数据面核同栈，类型/代码可渐进共享。

**成本 / 需承担**
- 多一道 FFI 边界要养：UniFFI 升级、每端 dispatcher hop、绑定随构建重生成。
- 每端跨语言打包：Apple xcframework、Android cargo-ndk `.so` + Gradle/JNA(aar)（已验证，但 moving
  parts 多，需每端 CI；spike 暴露过本机大下载不稳，CI 要用可续传/pin 版本规避）。
- 调试跨 FFI 边界（Rust panic → 错误码，不如全原生栈跟踪顺）。

**不立即改的（迁移立场，避免范围爆炸）**
- **现有 macOS Swift `MiniVPNCore` + SwiftUI app 不推倒重写**：它是可用的 macOS 客户端，且作为
  契约/状态机的**参照 oracle**继续服役。
- C 是**向多端推进时的前进方向**：Rust core 增量构建（数据面已在；控制/业务逻辑随第二平台
  Android 落地时迁入），Swift 侧逐步切到消费 Rust core。

## 待定的设计点（建第二平台时定，不阻塞本 ADR）

- **FFI 线画在哪**：薄核（仅数据面 + 控制客户端在 Rust，view-model 仍原生）vs 厚核（状态机/
  view-model 也进 Rust，UI 纯渲染）。spike 证明"service + 状态机 + async 流过 FFI"可行 → 倾向
  **偏厚核**以最大化共享，UI 只做渲染 + 平台习惯。
- **Rust vs KMP**：本 ADR 选 Rust（与数据面核同栈、已验证）；KMP 作为未来对比项不在本轮。
- **契约共享**：Rust core 的类型与 `contracts/` 对齐机制（与 core 仓的共享待 core session 空闲）。

## 仍属"税"、A/C 都付、只有账号持有者能做的真实步骤（非设计风险）

- Apple：开发者后台给 App ID 开 **NetworkExtension capability** + 签 provisioning，才能真加载
  packet-tunnel 扩展跑隧道。
- Android：`VpnService` + 系统 VPN 同意弹窗（更轻，无 Apple 式 entitlement 申请）。
