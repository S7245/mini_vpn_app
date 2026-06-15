# 前端工程设计：契约先行 + macOS 原生先行

- 日期：2026-06-12
- 状态：已批准（设计阶段完成，待转实施计划）
- 关联 core 仓：`../mini_vpn`（数据面 VPN 核心，本工程不修改它）

## 1. 背景与问题

core（`mini_vpn`）是一个 learning-oriented 的数据面 VPN：TUN 拦截 → 用户态 TCP/IP →
TLS+Yamux / QUIC datagram 隧道到 Upstream。它仍在演进中。

需求：在 core 尚未完成时，并行启动多端前端（iOS / iPad / Mac / Android / Windows）。
约束（单人主力维护）下，要求"开发更快、测试与平台一致性更优"。

### 关键澄清：前端消费的不是数据面协议

core 里的 `relay_protocol.rs`、QUIC datagram、yamux、fake-IP 全是**数据面**，跑在
`客户端 core ↔ Upstream` 之间，前端 GUI 永不触碰。前端真正需要、且目前**完全不存在**的
是另外两层契约：

| 契约 | 双方 | 内容 | 现状 |
|---|---|---|---|
| ① 本地控制 API | GUI ↔ 本机 core | connect/disconnect、状态、实时流量、选节点、日志 | 无 |
| ② 远端后端 API | App ↔ 云端控制面 | 登录鉴权、订阅、节点列表+权重、配置下发 | 无 |

并行之所以可行：前端 mock 的是 ①②，与 core 的数据面演进互不阻塞。

## 2. 决策记录（为什么是这条路）

### 2.1 GUI 技术路线：原生 macOS 先行，全局栈决策延后（不全局押注）

考察过三条路线：

| | A. 原生单平台先行 + 契约先行 | B. Flutter 全平台 | C. 原生五端齐头并进 |
|---|---|---|---|
| 首平台出活速度 | 最快（无桥，已在 macOS）| 中（搭桥 + 工具链）| 慢（铺太开）|
| 单人维护税 | 最低（一次只扛一个 GUI 栈）| 中（4th 栈 + FFI 桥）| 最高（3 GUI + 3 CI + 3 签名）|
| 平台贴合度 | 高 | 低（处处外来感）| 高 |
| 网络 API 跟进 | 直连 OS，无滞后 | Flutter 可能滞后 | 直连，无滞后 |
| 锁死风险 | 最低（第二平台再定要不要 Flutter）| 较高 | 较高 |

**选 A。** 关键论证（对单人 + VPN 特有）：

1. **Flutter "帮你躲开原生生态" 对 VPN 是半个假象**：网络扩展（iOS
   `NEPacketTunnelProvider`、Android `VpnService`、Win 服务/WFP、macOS system
   extension）逼着你无论如何都得碰 Swift/Kotlin/C++。Flutter 只省 GUI 一层，且额外加
   一套工具链 + 一道 FFI 桥。VPN 的 GUI 很简单（开关/列表/流量/设置），为省简单 GUI
   多养一套栈 + 一道桥，单人来看常是净负。
2. **"单人铺 5 端原生" 是更大的范围陷阱**：3 套 GUI + 3 条 CI 矩阵 + 3 套签名打包 +
   跟 3 个 OS 升级周期，全压一个人；AI 写得快但 CI 矩阵、线上排障、版本适配不替你扛。
3. **契约先行让栈决策可延后**：现在锁契约（与平台栈无关），先用原生把一个平台做成真
   产品，全局栈决策留到第二平台、有数据时再做。

对原始两个子问题的诚实结论：
- "原生 + AI 更快吗"——**首平台：是**（已在 macOS，SwiftUI 无桥，AI 写 SwiftUI 强）；
  **五端齐发：否**（单人多平台维护税复利累积）。
- "测试/一致性更优吗"——一致性：原生赢"平台贴合"；测试：原生在矩阵层更差（N 条 CI），
  对单人是实打实的税。所以贴合度优势是真的，多平台测试税正是会咬单人的地方。

### 2.2 首平台：macOS

理由：开发者在 darwin、core 也在此调试；SwiftUI 一套未来顺带覆盖 iPhone/iPad/Mac；
无 FFI 桥，AI 辅助 SwiftUI 成熟。

### 2.3 后端 ②：最小真后端（Go + chi + sqlc + Postgres）

修订记录（2026-06-12，辩证复盘后改）：原定 Rust + axum + SQLite，经讨论改为
**Go + chi + sqlc + Postgres**。两点理由：

- **语言：Go**。控制面 API 是 IO 密集、非 CPU 密集，Rust 的性能优势用不上；这是开发
  速度 vs 维护成本之争。Go 在 CRUD/控制面出活更快、测试 ergonomics 更轻。决定性变量
  是维护者写 web 后端的个人速度/手感——维护者判定 Go 更顺，盖过"多一门语言"的税。
- **存储：Postgres 从第一天**。多用户商业服务是关系型、多用户、多写、要并发的负载，
  SQLite（单写者、嵌入式）是弱项；且确定要 Postgres，"先 SQLite 再迁"是假节省（迁移
  税 + 开发期没练到真并发/类型）。控制面用 Postgres 正命中"外部存储放控制面、不进数据
  面热路径"取向。代价：本地/CI 多一个 Postgres 依赖（docker 一条命令）。

**独立 Go module，与 core 仓彻底隔离**（契约语言中立，core 仍是 Rust）。

### 2.4 隔离约束

core 仓正被另一 session 使用，本工程必须与其物理隔离：独立目录、独立 git 仓，core 仓零
改动。① local-control schema 将来在 core session 空闲时再共享/对齐。

## 3. 架构

### 3.1 仓库结构（独立 monorepo）

```
mini_vpn_app/                      ← 新 git 仓，与 ../mini_vpn 隔离
  docs/specs/2026-06-12-frontend-contract-first-macos-design.md
  contracts/                       ← 单一事实源
    backend-api.openapi.yaml       ② App ↔ 云端
    local-control.schema.json      ① GUI ↔ 本机 core
    mock/*.json                    每个接口的样例响应
  macos-app/                       SwiftUI 工程（先吃 mock）
  backend/                         Go + chi + sqlc + Postgres（实现 ②）
```

### 3.2 两层契约的字段范围

**② backend-api（OpenAPI 3.1）** 首版三接口：
- 登录/换 token（auth）
- 节点列表（含权重、延迟、地区）
- 订阅套餐（plan）
- （后续）配置下发

**① local-control（JSON schema）** —— 首版只定**消息语义**，传输层（unix socket /
XPC / FFI）等接 core 时再绑（本就排在最后）：
- 命令：connect / disconnect / selectNode
- 状态机：disconnected → connecting → connected → error
- 实时流量流：上下行速率 + 累计字节（VPN GUI 的核心动效）
- 日志

### 3.3 mock 策略（解耦关键）

SwiftUI 内做**协议化 service 层**：`BackendService` / `ControlService` 各有 `Mock`
实现，从 `contracts/mock/*.json` 读数据。换真实现只换注入，视图 / 视图模型不动。

### 3.4 macOS app 组件（SwiftUI，菜单栏 + 主窗口）

连接开关、节点列表、实时流量仪表盘、日志面板、设置。菜单栏常驻（macOS 习惯）先做。

## 4. 落地顺序（每步独立验收）

1. `contracts/` + mock 样例 —— 完成即解锁前后端并行
2. backend 最小真实现（②）：Go + chi + sqlc + Postgres
3. macOS app 对着 mock 跑通 5 个页面 → 再切真后端 ②
4. （延后）① local-control 接 core —— 依赖 core 成熟度，排最后，不阻塞 1–3

## 5. 测试与一致性

- **契约即一致性边界**：backend 与 app 都对同一份 spec 做符合性校验，这是跨层一致性的
  来源（比"同一套 UI 代码"更本质）。
- contracts：OpenAPI 校验 + mock 符合性检查。
- backend：Go 集成测试打 ② 接口（httptest + 真 Postgres，如 testcontainers / dockertest）。
- macOS：service 层 + view model 单测（mock 驱动）+ 视图快照测试。

## 5b. 业务需求（契约级，2026-06-12 补充）

产品形态：**多用户商业服务**。以下语义被 `contracts/` 冻结到字段粒度。

### 鉴权：邮箱 + 密码

- 接口：register / login / refresh / logout / change-password。
- token：access + refresh。
- 第三方登录（Apple / Google）作为后续项预留，首版不做。

### 订阅：时长制（不限流量，按到期）

- 字段：`plan`、`status`(active / expired)、`expires_at`、`device_limit`。
- 到期停服；不计流量、无配额。

### 设备：device_limit 的衍生面（首版进契约）

- 接口：设备注册 / 列表 / 解绑，用于卡并发设备数。
- 这是 `device_limit` 能落地的前提。

### 节点：手动选 + 自动优选 + 独享静态 IP

- **共享节点**字段：`region` / `city` / `latency` / `load` / `tier`。
- **独享节点**：`kind=dedicated` 的静态 IP，归属当前用户、独立 `expires_at`、可自定义
  `label`，出现在该用户的节点列表里。
- 自动优选：`selectBest` 语义（按延迟 / 负载）；手动选则直接给 `nodeId`。

### ① local-control 语义（仅定义，传输层延后）

- 状态机：`disconnected → connecting → connected → error`。
- 命令：`connect(nodeId) / disconnect / selectNode / auto`。
- 实时流量流：上下行速率 + 累计字节。
- 日志流。

### 两个已确认的默认值

1. **支付/购买流程首版不实现**：契约保留订阅状态、独享 IP 拥有状态等只读字段，及购买
   接口的占位 stub（返回 not-implemented）；真正支付集成排后续。
2. **独享静态 IP 建模**：作为 `kind=dedicated` 节点 + 独立 `expires_at` 挂用户名下，
   购买入口后续再做。

## 6. 明确不做（YAGNI / 范围边界）

- 不在本阶段做 Android / iOS / Windows GUI（A 路线：第二平台再决策栈）。
- 不在本阶段实现 ① 的真实传输层与 core 对接（仅定语义）。
- 不引入 Flutter / 跨平台 GUI 框架。
- 后端不上 Postgres / Redis / 服务发现（控制面后续话题，非首版）。
- **不实现支付/购买流程**（仅留只读状态字段 + not-implemented 占位接口）。
- 不修改 core 仓任何文件。

## 7. 待后续阶段处理

- ① local-control 传输层落地（unix socket / XPC / FFI）与 core 对接。
- 第二平台（Android / Windows）落地时的全局 GUI 栈复盘（继续原生 vs 引入 Flutter vs 共享 Rust core + 薄原生 UI）。**触发器、输入清单与判据见 §7.1**——这是个可勾选的 gate，不是"以后再说"。
- 后端加配置下发、服务发现 / 节点健康与权重动态化（Postgres 已从第一天起用）。
- 支付 / 购买流程（订阅续费、独享 IP 购买）的真实实现与支付渠道集成。
- 第三方登录（Apple / Google）。
- 契约在 core 仓与本仓之间的共享机制（待 core session 空闲对齐）。

### 7.1 第二平台 GUI 栈复盘：触发器与判据

§2.1 把全局栈决策**故意延后**到有数据时再做。本节把它钉成一个可触发、有输入、有
判据的 gate，避免它退化成永不发生的"以后再说"。

**触发器（event-based，满足任一即启动复盘）：**

- [ ] 出现要落地一个**非 Apple 平台（Android / Windows）**的具体决定（有真实用户/商业
  理由）。注意：iPhone / iPad 复用同一套 SwiftUI，**不触发**复盘——那只是增加 target。
- [ ] （提前触发的 forcing signal）单 macOS 的维护税已明显超预期（CI / 签名 / OS 适配
  吃掉大量时间），即便第二平台尚未排期。

**复盘前必须收齐的输入（用 macOS 这一程的实测值替换 §2.1 表里的推测）：**

- [ ] **可移植层 vs UI 层的比例**：Core 包（service/VM/models，纯逻辑、`swift test` 全
  覆盖）相对 View 的体量；以及"再写一个客户端"到底要重写多少（注意 Core 现为 Swift，
  跨到 Android/Win 要换语言重写）。
- [ ] **单平台维护税实感**：一条 CI + 一套 xcodegen/签名的真实开销，乘 N 平台后的数。
- [ ] **VPN 网络扩展的不可避税**：核实 §2.1 的核心论点"Flutter 只省 GUI 一层，网络扩展
  每平台都得碰原生"在 Android `VpnService` / Windows WFP 上是否依然成立（macOS system
  extension 落地后此数据才完整）。
- [ ] **AI 写原生 UI 的实际速度**：SwiftUI 这程的出活速度能否复制到 Kotlin / C# / Dart。
- [ ] **契约稳定度**：①/② 是否已稳到"第二客户端只是重新绑定契约"。

**判据（重跑 §2.1 的四变量，用证据不用猜）：**

- [ ] 单人维护税 · 平台贴合度 · 网络 API 跟进滞后 · 锁死风险
- [ ] 新增变量：下一个平台具体是哪个、需求多强

**候选选项（契约先行解锁了第三条）：**

- [ ] **A 延续**：原生逐平台（贴合度最高、维护税最高）。
- [ ] **B**：引入 Flutter / 跨平台 GUI（省 GUI 层，加一道 FFI 桥 + 一套工具链）。
- [ ] **C（新）**：把可移植层（service/VM/models）沉到**共享 Rust core 经 FFI**，每平台
  原生薄壳 UI。macOS 这程已证明 UI 极薄、逻辑都在 Core；数据面 core 本就是 Rust、契约
  又语言中立，故"逻辑写一次（Rust / 或 KMP）+ 薄原生 UI"是 §2.1 当时没充分权衡、现在
  变现实的路。复盘必须认真评这一条。

**产出：** 与第一次决策对称，写一份 ADR / §2.1 修订记录，写明"在 X 数据下选了 Y、为什么"。
不口头化。
