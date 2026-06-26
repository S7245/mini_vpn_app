# Android App Implementation Plan

- 日期：2026-06-25
- 状态：草拟（待 grill/确认 → 转执行）
- 关联：[ADR GUI 栈=C](../adr/2026-06-19-gui-stack-c-shared-rust-core.md)、[iOS PRD](../prd/2026-06-24-ios-app-prd.md)、[iOS plan](2026-06-19-ios-app.md)、FFI spike `spikes/rust-ffi-ui/FINDINGS.md`、网络扩展税 `spikes/macos-netext/TAX.md`

> **Android 与 iOS 的根本区别**：iOS 与 macOS 同属 Apple/SwiftUI 栈，直接复用 Swift `apple-core`、零 FFI。
> Android 是 Kotlin/JVM，**不能**复用 Swift。按 ADR-C，Android = **共享 Rust core（经 UniFFI 暴露 Kotlin）
> + Compose 薄原生 UI**。所以 Android 的"共享层"要先**产品化出来**（iOS 阶段不需要这一步）。
> FFI 机制已被 5 段 spike 端到端验证（含 Android arm64 `.so` + Kotlin/JNA + tokio/async 真模拟器跑通）。

## 0. 需求整理（scope，与 iOS 同产品）

功能范围与 iOS 一致、**需求权威同一份 [iOS PRD](../prd/2026-06-24-ios-app-prd.md)**（FR/字段表/状态机/四态都是平台中立的，Android 复用；只有视觉设计走 Material 而非 HIG）：
- 屏幕（底 3-tab + 鉴权前置）：Login、Register、Connect、Nodes、Account。**Logs 不做**。
- 鉴权 login/register/logout（记住登录）；change-password 不做。
- 设备列表 + 左滑/长按解绑（当前设备不可解绑，Q-02）。
- 节点 shared/dedicated + 手动选 + 自动优选 + 选中接线到连接（FR-09）；过期 dedicated 置灰（Q-01）。
- 连接状态机 + 实时流量。
- **mock-first**：吃 `contracts/mock`；真后端②/真隧道①（Android `VpnService`）延后。

## 1. 架构

### 两层
```
rust-core/                 ← 新建：GUI 共享的控制/业务逻辑 Rust crate，UniFFI 暴露 Swift+Kotlin
  （以 Swift apple-core 为移植参照 oracle；与数据面仓 ../mini_vpn 分开、零触碰）
android-app/               ← 新建：Compose 原生 app，消费 rust-core 的 Kotlin 绑定 + arm64 .so
```

### rust-core 里放什么 / Kotlin 侧放什么（关键决定）

参照 Swift `apple-core` 的分层（models / services / view-models / 状态机），Android 的切法：

| 层 | 放哪 | 说明 |
|---|---|---|
| models（TokenPair/Subscription/Device/Node/SelectBest） | **Rust core** | UniFFI 生成 Kotlin data class；契约解码一处 |
| ① ControlService（连接状态机 + 事件流 + 命令） | **Rust core** | spike 已有 Rust 实现（broadcast + tokio/async），产品化 |
| ② BackendService（鉴权/节点/订阅/设备，mock 读 fixture） | **Rust core** | 同一份 `contracts/mock` |
| view-model（StateFlow + 命令编排） | **Kotlin 薄 VM** | Compose 惯用 `ViewModel`+`StateFlow`；薄壳调 Rust service、把事件流 map 成 StateFlow |
| UI | **Compose** | Material 3 |

> **取舍说明**：ADR 倾向"厚核"。Android 首版取**务实中核**——把最易漂移的部分（契约解码、后端客户端、
> 连接状态机）放 Rust 共享；VM 留薄 Kotlin（Compose/StateFlow/生命周期惯用法）。这已覆盖跨端共享的主体；
> 日后可把更多 VM 逻辑下沉 Rust。回调线程：Rust 事件在 Rust 线程到达 → Kotlin 侧 `withContext(Dispatchers.Main)`
> / map 到 StateFlow（spike 已验证）。

### 复用 spike 的成果（不是从零）
- `spikes/rust-ffi-ui` 已有：可工作的 Rust UniFFI `ControlService`（sync 回调 + tokio/async + broadcast）、
  Kotlin 绑定生成、`cargo-ndk` 出 arm64 `.so`、Gradle+JNA(aar) 消费、真模拟器跑通。**rust-core 与 android-app 是它的产品化。**

## 2. 阶段（Rust core 先行 → 外壳 → 设计 → 模块）

> 与 iOS 不同：iOS 的共享层（apple-core）已存在，Android 必须**先把 rust-core 建出来**。

### Phase 1 — rust-core 骨架 + 首切片（① ControlService）
- 新建 `rust-core/`（cargo crate，UniFFI proc-macro，`crate-type=["staticlib","cdylib","lib"]`，`uniffi-bindgen` bin shim）。
- 切片①：models + `ControlService`（连接状态机 + 事件流 connect/disconnect/selectNode/auto；state/stats/log/error）——以 Swift `MockControlService` 为 oracle，spike 的 Rust 版为种子。
- `cargo test`（Rust 单测：状态机/事件序）；生成 Kotlin 绑定；`cargo ndk -t arm64-v8a` 出 `.so`。
- 验收：cargo test 绿 + 绑定生成 + `.so` 是 arm64 ELF。

### Phase 2 — Android app 外壳（Compose + 会话 gate）✅ 完成（commit `af8c615`，2026-06-25）
- `android-app/`：Gradle 工程（AGP 8.7.3、Kotlin 2.0.21、Compose、minSdk 24、target/compile 35、abi=arm64-v8a）。gradlew wrapper → gradle 8.12（命中本地 wrapper 缓存，零下载）；Gradle 跑在 AS 自带 JBR（JDK21）。`buildToolsVersion=35.0.1` 规避 AGP 自动下载 build-tools 34（spike 踩过的 ZipFile 截断坑）。
- 集成 rust-core（`minivpn_core`）：`build-android.sh` 一键 cargo-ndk 出 arm64 `.so` → 拷 jniLibs/arm64-v8a → 重生成 UniFFI Kotlin 绑定到 app 源码 → `gradlew assembleDebug`。deps：`net.java.dev.jna:5.14.0@aar` + `kotlinx-coroutines-android`。`.so`/生成绑定/build 产物/local.properties 全 gitignore（`build-android.sh` 是其唯一真源）。
- 控制层：`ConnectionViewModel`（薄 Kotlin VM over rust-core `ControlService`）——`EventObserver.onEvent` 在 Rust ticker 线程到达，先 `Dispatchers.Main` hop 再更新 `StateFlow`（FINDINGS §8 线程规则）。`send(Connect/Disconnect)` 经 FFI 驱动；disconnect 走 `Dispatchers.IO`（rust-core `stop()` join ticker，避免卡主线程）。
- 会话 gate（占位本地 bool；真 auth = Phase 4 切片②）：未登录→Auth 占位 / 已登录→3-tab（Connect/Nodes/Account）。Connect 占位屏 `send(Connect)` 驱动状态机，实时 state + 1Hz stats 回流到 UI。
- 验收（已过）：`./gradlew assembleDebug` 出 APK；装上 AVD `Medium_Phone_API_36.0`（arm64）启动；adb 驱动 Connect → logcat（tag `MiniVPN`）见 `CONNECTING→CONNECTED` + 累加 stats，Disconnect → `DISCONNECTED` + ticker 停，全部在 `[main]` 落地（证明 rust-core→FFI→UI 链路活）。`/code-review` 已跑（修了 disconnect 主线程阻塞 + 未用 import）。

### Phase 3 — 设计 UI（Material 3）✅ 完成（commit `bfd8db0`，2026-06-26）
- 同一产品、同一 PRD 需求；视觉走 **Material 3**（底部导航、Material 卡片、Material 配色/动态色），非照搬 iOS HIG。
- 逐屏出 Material mockup（Login/Register/Connect/Nodes/Account）→ **已过目确认** → 实现。
- 设计决策（过目时定）：**Dynamic Color（Material You）**，API 31+ 取系统壁纸色、低版本回退品牌 seed，light/dark 全支持（Q-A3）；**Connect 用 Material 大按钮**（非 iOS 圆环），状态色（已连接=绿 / 连接中=amber / 出错=红 / 未连接=中性）；每个 tab 屏一个 **CenterAligned TopAppBar**。
- 实现（Compose）：`ui/theme/`（MiniVpnTheme + StatusColors）、`ui/auth/`（Login/Register，M3 OutlinedTextField + 密码显隐 + 确认不一致 error 态）、`ui/connect/`（接 Phase 2 实时 ConnectionViewModel——大状态钮 + 节点卡 + Download/Upload 流量卡）、`ui/nodes/`（Auto-select + 节点列表 + dedicated chip + load% + 选中 + 过期置灰不可选 Q-01）、`ui/account/`（订阅卡 + 设备列表 + 左滑解绑 Q-02 + 登出）。`ui/model/UiModels.kt` 为静态样例数据，Phase 4 由 rust-core 切片②替换、composable 不变。
- 验收（AVD arm64 逐屏截图）：5 屏全渲染；Connect connect→connected 实时 stats（rust-core over FFI）；Nodes 选中/过期置灰；Account「active」绿 chip。`/code-review` 已跑（无 correctness finding 存活；清理 2 处）。
- 注：左滑解绑为 M3 `SwipeToDismissBox` 教科书模式，但 `adb input swipe` 合成手势无法驱动 Compose AnchoredDraggable（已知限制），真机手势验证留 Phase 4 instrumented 测试。

### Phase 4 — 切片② BackendService + 按模块实现
- rust-core 切片②：BackendService（鉴权/节点/selectBest/订阅/设备/revoke），mock 读同一 `contracts/mock`；cargo test。
- 按模块（Compose 屏 + 薄 Kotlin VM over Rust service，能测则 TDD）：
  - **A1 Auth**：SessionStore（DataStore/EncryptedSharedPrefs，记住登录）+ Auth VM + Login/Register。
  - **A2 Connect**：连接屏（状态色开关 + 实时流量），VM 订阅 Rust ControlService 事件流。
  - **A3 Nodes**：节点列表 + 选中 + 自动优选 + FR-09 接线 + 过期置灰。
  - **A4 Account**：订阅 + 设备 + 解绑（Q-02）+ 登出。

### 延后（不在本里程碑）
- Android `VpnService` 真隧道（系统 VPN 同意弹窗 + `BIND_VPN_SERVICE`；比 Apple 轻，无 entitlement 申请）。
- 真后端②切换（rust-core 内 mock→real 一处切换）；iPad/平板、第三方登录、支付、埋点。

## 3. 测试与一致性
- **rust-core**：`cargo test`（models 解码 / 状态机 / mock service），对着同一 `contracts/mock` fixture。
- **Kotlin VM**：JUnit + coroutines-test（薄 VM 的 StateFlow 行为）。
- **契约一致性**：Rust 解码权威 fixture（与 Swift apple-core 解码同一份），跨端一致由契约保证。
- **app**：`gradlew assembleDebug` + arm64 AVD 冒烟（启动/登录/连接）。
- 注：本机大文件下载偶发慢/截断（spike 踩过）——Gradle 依赖/NDK 用可续传或复用已装版本规避。

## 4. 约束
- 仅在 `mini_vpn_app-macos` worktree 操作；提交 `feat/macos-app`，push `origin/feat/macos-app`，绝不 push main。
- **零触碰** `../mini_vpn`（数据面 core 仓）、`../mini_vpn_app`、`../mini_vpn_app-backend`。
- `contracts/` 权威，fixture 同步不手改副本。
- 环境已就绪（rust+targets+NDK r25c+cargo-ndk；Android Studio+SDK35+build-tools34/35/36+arm64 AVD+JDK17）。

## 5. 待定/开放（开工前可一并定）
- **Q-A1 rust-core 落点/命名**：`rust-core/`（默认）。是否同时把 macOS/iOS 也切到消费 rust-core？**默认否**——Apple 端继续吃 Swift `apple-core`（已工作、是 oracle），rust-core 先只服务 Android；Apple 端是否迁移留后续单独决策。
- **Q-A2 核薄厚**：默认"中核"（services+状态机进 Rust，VM 留薄 Kotlin）。要不要更厚（VM 也进 Rust）？
- **Q-A3 设计**：~~Material 3 原生（默认）vs 尽量贴 iOS 观感统一~~ → **已定：Material 3 原生 + Dynamic Color + light/dark**（Phase 3）。
- **Q-A4 SessionStore 实现**：DataStore vs EncryptedSharedPreferences（记住登录；mock 阶段明文 token 即可，真实现加密）。
- **Q-A5 分支**：~~继续 `feat/macos-app`（默认，monorepo）vs 拆 `feat/android`~~ → **已定：`feat/macos-app`**（Phase 2）。
- **Q-A6 cargo-ndk ↔ Gradle 集成**：~~先手动拷 `.so`（快）vs 直接上 cargo-ndk Gradle 插件~~ → **已定：`build-android.sh` 脚本化手动拷**（Phase 2；cargo-ndk Gradle 插件留作日后 CI 自动化）。
