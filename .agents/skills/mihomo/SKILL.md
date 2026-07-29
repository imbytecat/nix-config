---
name: mihomo
description: "Mihomo (Clash Meta) 代理内核参考。用于 Mihomo 配置、TPROXY 设置、代理规则或订阅管理。触发词: mihomo, clash meta, tproxy, proxy rules, subscription config。"
---

# Mihomo 参考指南

## 官方资源

| 资源     | 地址                                              | 用途           |
| -------- | ------------------------------------------------- | -------------- |
| 文档     | https://wiki.metacubex.one/config/                | 配置参考       |
| 源码     | https://github.com/MetaCubeX/mihomo/tree/Meta     | 实现细节       |
| Alpha 分支 | https://github.com/MetaCubeX/mihomo/tree/Alpha   | 最新特性       |

**注意**: 只使用 Meta 或 Alpha 分支，其他分支可能有问题。

## CLI 用法

```bash
mihomo -h              # 帮助
mihomo -t -f <config>  # 验证配置 (0=成功, 1=失败)
mihomo -d <dir>        # 设置配置目录
mihomo -f <file>       # 指定配置文件
```

## TPROXY 必需字段

```yaml
tproxy-port: 7894      # TPROXY 监听端口
mixed-port: 7890       # HTTP+SOCKS5 混合代理端口
```

**注意**: 本项目不设置 `routing-mark`。因为 nftables 只有 PREROUTING 链（无 OUTPUT 链），
Mihomo 出站流量不会被拦截。若设置 routing-mark，ip rule 会将出站流量路由回本机，导致死循环。

## 常用模式

### 先验证后应用

```bash
curl -fsSL "$URL" -o /tmp/config.yaml
mihomo -t -f /tmp/config.yaml && mv /tmp/config.yaml /etc/mihomo/config.yaml
```

### 强制注入 TPROXY 字段

```bash
yq -i '.tproxy-port = 7894 | .mixed-port = 7890' config.yaml
```

## TPROXY 排查手册

### rp_filter 陷阱（已踩坑并修复）

**症状**: DNS 返回 fakeip 正常，但 TCP 连接超时（ERR_CONN_TIMED_OUT）。nftables TPROXY 规则有计数但 mihomo 无流量。

**根因**: Linux `rp_filter` 有效值 = `max(conf.all, conf.INTERFACE)`。NixOS 内核默认给每个接口 `rp_filter=2`，仅设 `conf.all=0` + `conf.default=0` 无效（`default` 只影响新建接口）。

**为什么 rp_filter 会丢包**: TPROXY 的路由表有 `0.0.0.0/0 local`，反向路径查找返回 `RTN_LOCAL`，但包从 ens18（非 loopback）进入，内核判定 RTN_LOCAL 不应从非 loopback 到达 → 丢弃。丢包位置：`ip_rcv_finish_core`。

**修复**: 通过 systemd-networkd 逐接口禁用：

```nix
# modules/gateway/default.nix — 物理网卡
systemd.network.networks."50-lan".networkConfig.IPv4ReversePathFilter = "no";

# modules/gateway/tproxy.nix — loopback
systemd.network.networks."99-tproxy" = {
  matchConfig.Name = "lo";
  networkConfig.IPv4ReversePathFilter = "no";
  # ... routes & rules
};
```

**不需要 `src_valid_mark`**: `rp_filter=0` 时反向路径检查完全跳过，不需要 `src_valid_mark=1`。

### AF_NETLINK 陷阱（已踩坑并修复）

**症状**: TCP 代理完全正常，但所有 UDP DIRECT 失败。日志刷屏：
```
[UDP] dial DIRECT ... error: route ip+net: netlinkrib: address family not supported by protocol
```
表现为客户端 QUIC、DNS over UDP、NTP、Tailscale/WireGuard、游戏联机全部不通。

**根因**: NixOS 上游 `services.mihomo` 单元默认 `RestrictAddressFamilies="AF_INET AF_INET6"`。Go 的 `net/route.FetchRIB`（UDP DIRECT dialer 用来枚举路由/选接口）依赖 `socket(AF_NETLINK, ...)`。被 seccomp 挡掉后返回 `EAFNOSUPPORT`。TCP DIRECT 走 `net.Dial`，内核直接路由，不触发 netlink 枚举，所以不受影响。

**修复**: 在 `modules/gateway/mihomo.nix` 的 `systemd.services.mihomo.serviceConfig` 里放开 AF_NETLINK：

```nix
RestrictAddressFamilies = lib.mkForce [
  "AF_INET"
  "AF_INET6"
  "AF_NETLINK"
];
```

**定位方法**: `systemctl show mihomo | grep RestrictAddressFamilies` 看当前限制；mihomo 日志里 `netlinkrib` 关键字 = 该问题的指纹。

### CAP_NET_BIND_SERVICE 陷阱（已踩坑并修复）

**症状**: TCP 一切正常，UDP 高端口正常（STUN 3478 通），但**目标端口 <1024 的 UDP 回包全丢**。
日志刷屏：
```
level=error msg="listenLocalConn failed with error: permission denied, packet loss (rAddr=1.2.3.4:443 lAddr=10.24.2.201:57595)"
```
表现为客户端 QUIC/HTTP3（UDP 443）、NTP（123）静默黑洞。App 要等 QUIC 超时才回落
TCP —— 闲鱼/手Q/微信 加载图片"莫名慢一两秒"就是这个。非 CN QUIC 常被规则 REJECT
（快速失败无感），所以**只有国内 App 表现异常**，极易误判。

**根因**: `listener/tproxy/packet.go` 的 `createOrGetLocalConn` 走 UDP 回程时，会新建
socket 并 `bind` 到**原始目标 addr:port** 来伪造回包源地址（客户端必须看到回包来自它
发往的地址）。上游 `services.mihomo` 用 `DynamicUser=yes`，非 root bind <1024 端口需要
`CAP_NET_BIND_SERVICE`，否则 `EACCES`。`IP_TRANSPARENT` 只需 CAP_NET_ADMIN/CAP_NET_RAW，
所以非特权端口的 UDP 一切正常，掩盖了问题。

**修复**: `modules/gateway/mihomo.nix` 里 mkForce 的 caps 必须两个都给：

```nix
AmbientCapabilities = lib.mkForce [ "CAP_NET_ADMIN" "CAP_NET_BIND_SERVICE" ];
CapabilityBoundingSet = lib.mkForce [ "CAP_NET_ADMIN" "CAP_NET_BIND_SERVICE" ];
```

**定位方法**: 客户端做 A/B —— 特权端口 UDP（NTP 123）失败、高端口 UDP（STUN 3478）成功，
即可锁定。`journalctl -u mihomo | grep listenLocalConn` 是该问题的指纹。
`grep CapAmb /proc/$(pgrep -x mihomo)/status` 应为 `1400`（bit 10 + bit 12）。

### 排查流程（从上到下）

1. **确认基础设施**:
   - `ip rule show` — 有 `fwmark 0x1a0a lookup 100`
   - `ip route show table 100` — 有 `local default dev lo`
   - `nft list ruleset` — TPROXY 规则存在
   - `ss -tlnp | grep 7894` — mihomo 在监听
   - `lsmod | grep tproxy` — `nft_tproxy`, `nf_tproxy_ipv4` 已加载

2. **确认流量到达 nftables**: 给 TPROXY 规则加 `counter`，看是否有包匹配

3. **确认 mihomo 能力**: `getpcaps $(pidof mihomo)` 需含 `cap_net_admin`

4. **定位丢包点（关键）**:
   ```bash
   perf trace -e skb:kfree_skb --filter 'reason != 0' -a -- sleep 5
   # 或
   cat /sys/kernel/debug/tracing/events/skb/kfree_skb/format  # 查看可用字段
   echo 1 > /sys/kernel/debug/tracing/events/skb/kfree_skb/enable
   cat /sys/kernel/debug/tracing/trace_pipe
   ```
   如果大量丢包在 `ip_rcv_finish_core` → rp_filter 问题。

5. **验证 rp_filter**:
   ```bash
   sysctl net.ipv4.conf.{all,default,ens18,lo}.rp_filter
   # 有效值 = max(all, 接口)，任何接口 >0 都会导致 TPROXY 丢包
   ```

### 关键设计决策

| 决策 | 原因 |
|------|------|
| 不设 `routing-mark` | nftables 只有 PREROUTING 链，无 OUTPUT 链，mihomo 出站不会被拦截。设了反而会死循环 |
| 不设 `src_valid_mark` | rp_filter=0 时不需要 |
| 用 networkd 而非 sysctl 禁 rp_filter | sysctl `default` 只影响新建接口，对已存在接口无效 |
| DNS 劫持用 `dstnat` + `redirect` | 比 TPROXY 简单，DNS 只需改目标端口 |
| 关 `profile.store-fake-ip` | 首见域名要两次 bbolt Batch（各 10ms MaxBatchDelay + fsync），实测首次 A 查询 26ms → 0.2ms |
| 开 `sniffer` + `parse-pure-ip` | 走 HTTPDNS 的 App（闲鱼/手Q）直接用 IP 建连，实测约 1/4 连接无域名，域名规则全失配 |
| ip6 forward 用 `reject` 而非 `drop` | 静默丢包会让客户端 Happy Eyeballs 干等 1~3s 才回落 IPv4 |
| DNS 劫持链首条 `iif lo return` | 本机 stub(127.0.0.53) 的查询也过 prerouting，被劫进 mihomo 会拿到 fake-ip，而本机没有到 fake-ip 的路由 → 网关自己拨不出去（订阅拉取失败） |
| 网关自身用 resolved DoT，不用 mihomo | 既避开 fake-ip，又不让恢复路径依赖 mihomo 存活 |
| `resolved` 必须开 `DNSStubListener` | 关掉时 resolv.conf 直接写上游 IP，glibc 绕过 resolved 明文查询，DoT 形同虚设 |
| 上游 DNS 只用「IP 字面量 DoH」 | 无需 bootstrap（无明文预解析）、不可被 UDP 投毒；实测复用连接后 7ms，与明文 UDP 53 同速 |
| `direct-nameserver` 单独配 | 直连域名（国内 CDN）不必绕订阅给的远端 DoH（28~40ms），且能拿到就近解析 |
| TPROXY 失败时 fail-open（不加 forward drop） | 已实测：mihomo 停止时 nft_tproxy 找不到 socket → 规则不匹配 → 内核照常转发，客户端脱代理直连。**这是明确选择的可用性优先**，代价是 mihomo 挂掉期间流量明文经 ISP 出去 |

### IP_TRANSPARENT 确认

mihomo 源码 `listener/tproxy/setsockopt_linux.go` 对 TCP 和 UDP 都设置了 `IP_TRANSPARENT`。`tproxy-port` 配置项和 `listeners` 配置项走同一代码路径。

## 查阅方法论

**关键**: 文档和源码需要交叉验证，两者都不完整。

1. **先查文档** - wiki.metacubex.one/config/ 获取配置选项和示例
2. **再查源码** - 验证实际默认值和行为
   - `config/config.go` - 配置结构定义
   - `main.go` - CLI 参数
   - `hub/executor/` - 运行时行为
3. **交叉验证** - 源码显示实际默认值，文档显示推荐用法
