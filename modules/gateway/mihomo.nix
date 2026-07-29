{
  pkgs,
  lib,
  ...
}:

let
  constants = import ./constants.nix;
  inherit (constants) tproxyPort mixedPort dnsPort;

  stateDir = "/var/lib/mihomo";
  configFile = "${stateDir}/config.yaml";
  envFile = "/etc/mihomo/env";

  baseConfig = {
    allow-lan = true;
    external-controller = "0.0.0.0:9090";
    tproxy-port = tproxyPort;
    mixed-port = mixedPort;
    find-process-mode = "off";
    ipv6 = false;
    # store-fake-ip 会在首次见到某域名时做两次 bbolt Batch 提交（各含 10ms
    # MaxBatchDelay + fsync），实测把首次 A 查询从 0.1ms 拖到 26ms。
    # 只为跨重启保留映射不值这个代价（fake-ip TTL 默认 1s，客户端很快重查）。
    profile.store-fake-ip = false;

    # CDN 多 IP 时并发拨号取最快，直连/代理都受益
    tcp-concurrent = true;
    unified-delay = true;

    # 闲鱼/手Q 等走 HTTPDNS 的 App 会直接用 IP 建连（实测约 1/4 连接无域名），
    # 域名规则全部失配只能落到 GEOIP/MATCH。嗅探 TLS SNI/HTTP Host 恢复域名，
    # 仅用于规则匹配（override-destination=false，不改实际目标）。
    sniffer = {
      enable = true;
      force-dns-mapping = true;
      parse-pure-ip = true;
      override-destination = false;
      sniff = {
        HTTP.ports = [
          80
          "8080-8880"
        ];
        TLS.ports = [
          443
          8443
        ];
        QUIC.ports = [
          443
          8443
        ];
      };
    };
    dns = {
      enable = true;
      listen = "0.0.0.0:${toString dnsPort}";
      ipv6 = false;
      # 直连出口的域名解析。用「IP 字面量 DoH」：无需 bootstrap、全程加密、不可被
      # UDP 投毒；实测复用连接后 7ms，与明文 UDP 53 同速（明文会把直连域名清单
      # 暴露给链路并可被伪造应答，禁用）。订阅自带的单个 DoH 实测 28~40ms。
      # 被代理的域名不走这里（由节点侧解析），因此不存在国内 DNS 污染问题。
      direct-nameserver = [
        "https://223.5.5.5/dns-query"
        "https://120.53.53.53/dns-query"
      ];

      # 解析「DNS 服务器自身域名」用的 bootstrap。订阅给的是明文 114/223/119，
      # 会在链路上暴露上游 DoH 端点域名，这里同样换成 IP 字面量 DoH。
      default-nameserver = [
        "https://223.5.5.5/dns-query"
        "https://120.53.53.53/dns-query"
      ];
    };
  };

  fallbackConfig = (removeAttrs baseConfig [ "external-controller" ]) // {
    mode = "direct";
    log-level = "info";
    dns = baseConfig.dns // {
      enhanced-mode = "redir-host";
      # 与 baseConfig 一致：只用 IP 字面量 DoH，全程无明文 DNS、无 bootstrap 依赖
      nameserver = baseConfig.dns.default-nameserver;
    };
  };

  yamlFormat = pkgs.formats.yaml { };
  baseConfigYaml = yamlFormat.generate "base-config.yaml" baseConfig;
  fallbackConfigYaml = yamlFormat.generate "fallback.yaml" fallbackConfig;

  subscribeScript = pkgs.writeShellScript "mihomo-subscribe" ''
    set -euo pipefail

    # 配置里有全部节点凭据和 API secret，任何中间产物都不许比 0600 宽
    umask 077

    if [ -z "''${CONFIG_URL:-}" ]; then
      echo "CONFIG_URL not set in ${envFile}"
      exit 0
    fi

    if [ -z "''${SECRET:-}" ]; then
      echo "SECRET not set in ${envFile}; required for external-controller API authentication"
      exit 1
    fi

    tmp="$(mktemp -p "${stateDir}" .mihomo-config.XXXXXX.yaml)"

    cleanup() {
      rm -f "$tmp"
    }
    trap cleanup EXIT

    echo "Fetching subscription..."
    curl -fsSL --connect-timeout 30 --max-time 120 \
      --retry 3 --retry-delay 2 --retry-all-errors \
      -o "$tmp" "$CONFIG_URL"

    echo "Sanitizing subscription..."
    yq -i '
      del(.routing-mark) |
      del(.tun) |
      del(.listeners) |
      del(.port) |
      del(.socks-port) |
      del(.redir-port) |
      del(.mixed-port) |
      del(.tproxy-port) |
      del(.allow-lan) |
      del(.bind-address) |
      del(.external-controller) |
      del(.secret)
    ' "$tmp"

    yq -i '. * load("${baseConfigYaml}")' "$tmp"

    SECRET="$SECRET" yq -i '.secret = strenv(SECRET)' "$tmp"

    echo "Validating configuration..."
    if ! output=$(mihomo -t -f "$tmp" -d "${stateDir}" 2>&1); then
      echo "Validation failed:"
      echo "$output"
      exit 1
    fi
    echo "$output"

    if [ -f "${configFile}" ] && [ "$(sha256sum < "$tmp")" = "$(sha256sum < "${configFile}")" ]; then
      echo "No changes; skip restart"
      exit 0
    fi

    if [ -f "${configFile}" ]; then
      install -m 0600 "${configFile}" "${configFile}.bak"
    fi
    mv -f "$tmp" "${configFile}"

    echo "Configuration updated; restarting mihomo"
    systemctl restart mihomo
  '';
in
{
  services.mihomo = {
    enable = true;
    configFile = configFile;
  };

  systemd.tmpfiles.rules = [
    "d /etc/mihomo 0750 root root -"
    # 含订阅 URL 与 API secret，手工创建时容易留成 0644
    "z ${envFile} 0600 root root -"
    "C ${configFile} 0600 root root - ${fallbackConfigYaml}"
  ];

  systemd.services.mihomo-subscribe = {
    description = "Fetch and validate Mihomo subscription";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "mihomo.service"
    ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = envFile;
    path = with pkgs; [
      curl
      yq-go
      mihomo
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = subscribeScript;
      EnvironmentFile = [ "-${envFile}" ];
      ReadWritePaths = [ stateDir ];
    };
  };

  systemd.timers.mihomo-subscribe = {
    description = "Periodic Mihomo subscription update";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnUnitActiveSec = "6h";
      Persistent = true;
    };
  };

  systemd.paths.mihomo-subscribe = {
    description = "Trigger subscription fetch when env file changes";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = envFile;
      Unit = "mihomo-subscribe.service";
    };
  };

  systemd.services.mihomo = {
    after = [
      "network.target"
      "nftables.service"
    ];
    wants = [ "nftables.service" ];
    requires = [ "nftables.service" ];

    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5s";

      # CAP_NET_BIND_SERVICE 必需：TPROXY UDP 回程 (listener/tproxy/packet.go
      # createOrGetLocalConn) 会新建 socket 并 bind 到「原始目标 addr:port」来伪造回包源地址。
      # DynamicUser 下 bind <1024 端口需要该 capability，否则 EACCES →
      # "listenLocalConn failed with error: permission denied, packet loss"
      # 后果：所有目标端口 <1024 的 UDP 回包被丢弃（QUIC/443、NTP/123）。
      AmbientCapabilities = lib.mkForce [
        "CAP_NET_ADMIN"
        "CAP_NET_BIND_SERVICE"
      ];
      CapabilityBoundingSet = lib.mkForce [
        "CAP_NET_ADMIN"
        "CAP_NET_BIND_SERVICE"
      ];
      PrivateUsers = lib.mkForce false;

      # 上游默认只允许 AF_INET{,6}；Go net/route.FetchRIB（UDP DIRECT dialer）需要
      # AF_NETLINK 枚举路由，否则所有 UDP DIRECT 静默失败。TCP DIRECT 不受影响。
      RestrictAddressFamilies = lib.mkForce [
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];

      LimitNOFILE = 1000000;
      StateDirectory = "mihomo";
    };
  };
}
