# OVH KS-5 裸机服务器调优调研

> 范围：x86_64 NixOS server、双 NVMe RAID1/ext4、DHCP、Docker、root-only、zramSwap、默认 nixpkgs 内核；当前没有声明网络 sysctl。本文只给可由官方资料支持的最小动作，不给未经测量的“万能”数值。

## 结论先行

- **BBR 值得作为低风险候选试验，但不是必然收益。** 它只改变本机发送方向的新 TCP 连接；对公网 TCP、长 RTT/有丢包或带宽-时延积较大的服务，BBR 按测得带宽和 RTT pacing，可能比仅基于丢包的拥塞控制减少排队并提高吞吐。对低延迟、小响应、UDP、应用/磁盘受限或已由上游整形的负载，收益可能不可见。必须用 p95/p99 RTT、重传、吞吐和 CPU/连接指标验证。
- **BBR 与 fq 应成对试验。** 上游 Kconfig 明确写 BBR requires fq；当前实现没有 fq 时会退回每 TCP socket 一个高精度定时器的内部 pacing，可能消耗更多资源。除非接口已有必须保留的整形/特殊 qdisc，否则最小试验就是 `bbr + fq`。
- **不存在通用 sysctl 清单。** TCP 缓冲区、backlog、文件上限、VM dirty、swappiness、NVMe/RAID 参数均应由实际瓶颈驱动。默认值是内核的资源边界与自动调优策略，不是待修复的错误配置。

## 本仓当前有效配置

这是对 flake 的评估结果，不代表服务器当前运行态：

- `ovh-ks-5` 使用 nixpkgs 默认 Linux `6.18.42`；其构建配置为 `CONFIG_DEFAULT_CUBIC=y`、`CONFIG_TCP_CONG_BBR=m`、`CONFIG_NET_SCH_FQ=m`。即默认算法仍是 CUBIC，但 BBR/fq 模块已经随内核提供，不需要更换内核。
- `boot.kernel.sysctl` 没有声明 `tcp_congestion_control` 或 `default_qdisc`；Docker 已带来的 IPv4 forwarding 不等于网络性能调优。
- `zramSwap` 已启用（zstd、内存比例 50%）；`services.fstrim.enable` 的有效值已是 `true`；Docker 日志驱动已是 `journald`。这些常见基线无需重复配置。
- `services.smartd.enable` 当前为 `false`。这不是性能问题；若服务器承载重要数据，应先接入 NVMe SMART、`/proc/mdstat` 与告警，再考虑更多性能旋钮。

复核命令：

```sh
nix eval --json --impure --expr 'let f = builtins.getFlake (toString ./.); c = f.nixosConfigurations.ovh-ks-5.config; in { kernel = c.boot.kernelPackages.kernel.version; sysctl = c.boot.kernel.sysctl; zram = { enable = c.zramSwap.enable; algorithm = c.zramSwap.algorithm; memoryPercent = c.zramSwap.memoryPercent; }; fstrim = c.services.fstrim.enable; smartd = c.services.smartd.enable; docker = c.virtualisation.docker.daemon.settings; }'
```

## BBR、pacing 与 fq

### 启用条件

1. 记录运行态基线。`tcp_available_congestion_control` 只列出当前已注册算法，模块尚未加载时不一定出现 `bbr`：

```sh
sysctl net.ipv4.tcp_available_congestion_control
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.default_qdisc
```

`tcp_congestion_control` 只影响新 TCP 连接（被动连接从监听 socket 继承）；来源：[Linux IP Sysctl](https://docs.kernel.org/networking/ip-sysctl.html#tcp-variables)。BBR 实现和 Kconfig 入口见：[Linux `tcp_bbr.c`](https://github.com/torvalds/linux/blob/master/net/ipv4/tcp_bbr.c)、[Kconfig](https://github.com/torvalds/linux/blob/master/net/ipv4/Kconfig)。

2. 加载本仓内核已有的模块，先试验 BBR；任一 `modprobe` 失败都应停止，而不是隐藏错误：

```sh
sudo modprobe tcp_bbr
sudo modprobe sch_fq
sysctl net.ipv4.tcp_available_congestion_control
tc -s qdisc show
sudo sysctl -w net.ipv4.tcp_congestion_control=bbr
# 只影响新连接；已有连接需重建后观察
```

`net.core.default_qdisc=fq` 只设置设备创建默认 qdisc，不应假定它会替换运行中接口的现有 qdisc；多队列物理网卡仍以 `mq` 为根、默认 qdisc 用于叶子，虚拟设备通常是 `noqueue`。因此 fq 配套试验应在维护窗口持久化后重启，再用 `tc -s qdisc show` 确认；不要对未知接口直接复制 `tc qdisc replace`。来源：[Linux net sysctl `default_qdisc`](https://docs.kernel.org/admin-guide/sysctl/net.html#default-qdisc)。

确认：

```sh
tc -s qdisc show
ss -tin
```

持久化的 NixOS 形态（仅在试验指标支持后提交）：

```nix
boot.kernel.sysctl = {
  "net.core.default_qdisc" = "fq";
  "net.ipv4.tcp_congestion_control" = "bbr";
};
```

NixOS 官方模块把 `boot.kernel.sysctl` 定义为启动时写入 `/proc/sys` 的属性集，源码：[nixpkgs `kernel.nix`](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/system/boot/kernel.nix)。本仓内核虽把 BBR/fq 编译为模块，但 Linux 的拥塞控制与默认 qdisc sysctl handler 都会按名称请求模块（[`tcp_cong.c`](https://github.com/torvalds/linux/blob/master/net/ipv4/tcp_cong.c)、[`sch_api.c`](https://github.com/torvalds/linux/blob/master/net/sched/sch_api.c)），所以最小 NixOS 配置就是上面两条 sysctl，不需要 `boot.kernelModules`，更不要放进 initrd。部署后若 systemd-sysctl 报模块不存在，应诊断内核/模块闭包，而不是继续堆配置。

### 适用场景与权衡

- 适合：公网 TCP 下载/上传、跨地域或高 BDP 连接、对排队延迟敏感且端到端允许 pacing 的服务。
- 不保证收益：短连接、小对象、应用/磁盘/CPU 已是瓶颈、UDP、局域网低 RTT，或上游出口已被硬件/运营商整形。
- 公平性：BBR 不以丢包作为唯一拥塞信号；与 Reno/CUBIC 等竞争时带宽分配、队列占用取决于 RTT、版本和瓶颈队列。共享瓶颈上可能出现对其他流不公平或队列延迟上升，必须测量而不是宣称“更快”。算法目标与 pacing 行为见 [BBR 论文（Google Research）](https://research.google/pubs/bbr-congestion-based-congestion-control/)、[Linux BBR 源码](https://github.com/torvalds/linux/blob/master/net/ipv4/tcp_bbr.c)。fq 的实现和 pacing 相关属性见 [Linux `sch_fq.c`](https://github.com/torvalds/linux/blob/master/net/sched/sch_fq.c)（qdisc 配置接口：[tc netlink spec](https://docs.kernel.org/netlink/specs/tc.html#tc-fq)）。

## 参数语义：不要盲调

| 参数 | 官方语义 | 本机建议 |
|---|---|---|
| `net.ipv4.tcp_rmem` / `tcp_wmem` | 三元组 min/default/max；TCP 自动调优的每 socket 内存边界，受 TCP 总内存压力和系统内存影响 | **仅有 BDP、并发连接、内存压力证据时改**；增大上限会乘以并发连接数 |
| `net.core.rmem_max` / `wmem_max` | socket 缓冲区上限；不等于每 socket 实际分配 | **仅应用明确需要更大 socket buffer 时改** |
| `net.core.somaxconn` | `listen()` backlog 的系统上限；应用传入值仍受其自身限制（Linux 5.4 起默认 4096，旧版 128） | 先看 `ListenOverflows`/应用 backlog；只改一项通常无效 |
| `fs.file-max`、进程 `RLIMIT_NOFILE` | 内核全局文件句柄上限与进程软/硬限制，不是网络吞吐旋钮 | 看到 `EMFILE`、句柄耗尽并确认服务需求后改；同步服务 unit 的 `LimitNOFILE` |
| `vm.swappiness` | 0–200 的 swap 与文件页回收相对倾向；默认 60；zram 属内存压缩 swap，成本模型不同 | zram 有内存压力/major fault 证据再调；不要因“服务器”统一设 0 |
| `vm.dirty_background_ratio` / `dirty_ratio`（及 bytes 版本） | 脏页达到后台写回阈值/节流高水位；ratio 随可用内存变化 | RAID/NVMe 写延迟、脏页堆积、写回抖动证据后再改；优先 bytes 或应用 I/O 设计 |

官方依据：[Linux net sysctl](https://docs.kernel.org/admin-guide/sysctl/net.html)、[Linux IP Sysctl](https://docs.kernel.org/networking/ip-sysctl.html)、[Linux VM sysctl](https://docs.kernel.org/admin-guide/sysctl/vm.html)、[Linux file-max 文档](https://docs.kernel.org/admin-guide/sysctl/fs.html)。这些值控制资源边界/写回策略；提高上限可能放大内存占用、队头等待或 OOM 风险，降低则可能造成吞吐下降和丢连接。

## Docker host 边界

Docker 官方把 `--sysctl` 定义为**容器网络命名空间级**参数，并限制可设置的 namespaced sysctl；Compose 也提供 service `sysctls`。见 [docker run `--sysctl`](https://docs.docker.com/reference/cli/docker/container/run/#sysctl)、[Compose services `sysctls`](https://docs.docker.com/reference/compose-file/services/#sysctls)。Linux 将新网络命名空间的默认 TCP 拥塞控制继承自 root namespace（[上游提交](https://github.com/torvalds/linux/commit/6670e152447732ba90626f36dfc015a13fbf150e)）：宿主先切到 BBR 后新建/重建的 bridge 容器会继承，已经运行的容器仍应逐个确认；host network 容器直接共享宿主网络命名空间（[Docker host network driver](https://docs.docker.com/engine/network/drivers/host/)）。部署重启后可用 `docker exec <container> sysctl net.ipv4.tcp_congestion_control` 验证。

Docker 的 bridge/nftables/转发需求另有明确配置，见 [Docker with nftables](https://docs.docker.com/engine/network/firewall-nftables/)；这不构成全局提高 buffers、somaxconn、file-max 的理由。只因“运行 Docker”不应套宿主机通用 sysctl，容器级特殊需求应留在对应 Compose service。

## 存储、RAID、swap

当前双 NVMe RAID1/ext4 已是明确的可靠性/读性能选择。没有 I/O 延迟、队列深度、重建状态或写放大数据，不建议改 scheduler、RAID stripe、ext4 mount 选项、discard、NVMe power policy。先记录 `iostat -x`, `cat /proc/mdstat`, `nvme smart-log`, `findmnt`；变更前保留可回滚配置。zram 不是免费 RAM：观察 `vmstat 1`、`/proc/meminfo`、major faults、容器 OOM 与压缩比，再决定 swappiness/zram 优先级。

## 可执行方案、验证与回滚

### 现在可直接做（低风险、可回滚）

1. **只读基线**：

```sh
uname -r; sysctl net.ipv4.tcp_available_congestion_control net.ipv4.tcp_congestion_control net.core.default_qdisc
tc qdisc show; ss -s; nstat -az | grep -E 'Tcp(Ext|Retrans|InErrs|OutRsts)'
free -h; swapon --show; vmstat 1 5; iostat -xz 1 5
cat /proc/mdstat; findmnt -no SOURCE,FSTYPE,OPTIONS /
```

2. 在维护窗口加载模块并临时切换 BBR；若运行态初测没有回归，再持久化 `bbr + fq`、重启并确认物理接口 qdisc。保留旧值：`sysctl net.core.default_qdisc net.ipv4.tcp_congestion_control`。
3. 观察至少覆盖真实高峰：吞吐、RTT（含 p95/p99）、重传、连接建立失败/ListenOverflows、CPU、内存/压缩、磁盘 await/util、RAID 状态。

### 仅有证据时启用

- BBR/fq 持久化；更大的 TCP/socket buffers；somaxconn 与服务 backlog 同步提高；`LimitNOFILE`/`fs.file-max`；swappiness/zram 优先级；dirty ratios/bytes；任何 RAID/ext4/NVMe 参数。
- 接受标准：目标指标改善且无回归（尤其 RTT 尾延迟、公平性、内存峰值、写回抖动、容器稳定性）；否则恢复旧值并重建连接。

### 不要做

- 不要复制网络博客的整套 sysctl；不把 `tcp_rmem/wmem`、`somaxconn`、`file-max`、dirty ratios 统一改成“大数”。
- 不要因 Docker、NVMe RAID1 或 zram 存在就宣称需要 host 级通用优化。
- 不要在未确认算法/模块存在时声明 `bbr`，不把模块无条件塞进 initrd，不在没有回滚路径时修改存储参数。

## 最小安全 NixOS 建议

当前默认配置已经合理；没有证据支持再加一整套“服务器优化”。若这台机器主要向公网发送跨地域 TCP 流量，唯一值得优先试验的是主机模块中的两条 `boot.kernel.sysctl`：BBR + fq。本仓内核已提供并可自动加载两个模块，不需要 `boot.kernelModules` 或自定义内核。部署后保留上一代 NixOS generation；RTT 尾延迟、重传、错误率、CPU 或吞吐恶化即回滚。
