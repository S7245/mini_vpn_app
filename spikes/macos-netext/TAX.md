# 网络扩展"不可避税"测量 → §7.1 的 A/C 决定尺

THROWAWAY SPIKE，2026-06-19。目标不是做出能跑的 VPN（受 entitlement 门控），而是
把"每平台不可避的原生工作量 vs 可共享逻辑"量化，回答 §7.1 还缺的最后一块 A/C 输入。
脚手架（本目录）编译通过（`** BUILD SUCCEEDED **`），证明结构/NE API 用法正确。

## 1. 三类工作面（按是否可共享切分）

| 工作面 | 内容 | 可共享？ | A 怎么做 | C 怎么做 |
|---|---|---|---|---|
| **NE 原生胶水** | provider 生命周期（startTunnel/stopTunnel）、`NEPacketTunnelNetworkSettings`、packetFlow 读写环、app 侧 `NETunnelProviderManager`、app↔ext IPC 传输、Info.plist/entitlements/签名/审批 | **不可共享**（Apple 专属；Android 是 VpnService + ParcelFileDescriptor，语义同、API 异） | 每平台原生写 | 每平台原生写 |
| **数据面**（隧道本体） | TUN 拦截后的用户态 TCP/IP、TLS+Yamux / QUIC datagram 到 Upstream、fake-IP | 可共享 | — | — |
| **控制/业务逻辑** | 后端 ② 客户端、节点选择、状态机、契约解码、流量/日志、① local-control 语义 | 可共享 | 每平台重写（Swift/Kotlin…） | **一次 Rust，FFI 消费** |

## 2. 决定性发现：数据面已经是 Rust，扩展无论 A/B/C 都得 FFI 进它

mini_vpn 的**数据面本体就是 Rust**（用户态 TCP/IP + QUIC/Yamux）。在 Apple 上，
`NEPacketTunnelProvider` 从 `packetFlow` 拿到包，必须喂给这套用户态栈再写回——也就是
**扩展进程内通过 FFI 调 Rust 数据面核**。Android 的 VpnService 同理（ParcelFileDescriptor
的 fd 循环 → 同一 Rust 核）。

没人会把用户态 TCP/IP + QUIC + Yamux 在 Swift 和 Kotlin 各重写一遍——那是荒谬的。所以：

> **每平台的网络扩展都必须在进程内 FFI-host 那个 Rust 数据面核，无论选 A/B/C。
> 即：FFI 边界不是 C 的额外成本，是 VPN 这个形态的既定前提。**

这把 A vs C 的差距压扁了：
- **A 的"全原生逻辑"是半个假象**——隧道本体仍是 Rust-over-FFI，A 真正"原生重写"的只是
  控制/业务逻辑（上表第三行），而扩展早已跨着 FFI 边界。
- **C 只是沿用同一道你已经为数据面跨的 FFI 边界**，把控制/业务逻辑也放进去共享。边际成本≈0，
  收益=控制逻辑不再 N 份漂移。

## 3. 量级（来自脚手架 + 已建的 macOS Core）

- **NE 原生胶水**：薄。本脚手架的 provider + manager 合计 ~150 行级，每平台一份，A/C 都付。
- **控制/业务逻辑**：厚且契约绑定。已建的 `MiniVPNCore`（services/VMs/models/状态机 + 测试）
  是其 Swift 投影；A 要在 Kotlin 再来一份，C 把它收进 Rust 核写一次。
- **数据面**：最厚，已是 Rust，A/C 都 FFI 复用。

## 4. entitlement / 签名 税（Apple 侧，A/B/C 都付，且只有账号持有者能开）

- packet-tunnel provider 需 `com.apple.developer.networking.networkextension`
  （见 `Extension/Extension.entitlements`）+ App ID 在开发者后台开 NetworkExtension
  capability + 对应 provisioning profile。本机有签名身份但**无该 profile**，故脚手架
  能编译、不能加载。Android 侧对应的是 `BIND_VPN_SERVICE` 权限 + 系统 VPN 同意弹窗（更轻，
  无 Apple 式 entitlement 申请）。
- 系统扩展还涉及 Developer ID + 公证（分发）或 `systemextensionsctl developer on`（开发）。

## 5. 对 §7.1 A/C 决定的结论

**这把尺量完，天平明确偏 C：**

1. B 已出局（§7.1 前述）。
2. A 与 C 都必须每平台写薄的 NE 原生胶水 + 都 FFI-host Rust 数据面核——**这部分一样**。
3. 唯一差别落在控制/业务逻辑：**A 每平台重写、C 写一次**。而 FFI 边界既然为数据面已经存在，
   C 把控制逻辑也放进去几乎是零边际成本、纯收益（消 N 路漂移、契约一处守）。
4. A 唯一净优势缩到"原生 view-model 逻辑 + 全原生调试栈"——是最小、最容易的那部分。

**建议**：把 §7.1 的 A/C 倾向更新为 **C 为首选**（VPN 数据面已 Rust 这一事实是决定性的）。
仍需账号持有者做的真实门控步骤（非设计风险）：开发者后台开 NetworkExtension capability + 签
provisioning，才能把隧道在真机/真扩展里跑起来——那是"税"的最后一段，A/B/C 都得付。
