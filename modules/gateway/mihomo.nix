{
  config,
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

  # 国内可用的 jsDelivr 边缘。
  geoMirror = "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release";

  baseConfig = {
    allow-lan = true;
    external-controller = "0.0.0.0:9090";
    tproxy-port = tproxyPort;
    mixed-port = mixedPort;
    find-process-mode = "off";
    ipv6 = false;
    # bbolt 两次 fsync 令首次 A 查询约 26ms；短 TTL 不值得持久化。
    profile.store-fake-ip = false;

    tcp-concurrent = true;
    unified-delay = true;

    # geo 由 mihomo 每 24h 更新，不 pin store；固定国内可用镜像，禁止订阅覆盖。
    geox-url = {
      asn = "${geoMirror}/GeoLite2-ASN.mmdb";
      mmdb = "${geoMirror}/country.mmdb";
      geoip = "${geoMirror}/geoip.dat";
      geosite = "${geoMirror}/geosite.dat";
    };

    # HTTPDNS App 常直接连 IP；嗅探 TLS SNI/HTTP Host 恢复域名供规则匹配。
    # override-destination=false，不改实际目标。
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
      # 直连域名使用 IP 字面量 DoH：无 bootstrap 或明文 UDP，复用后约 7ms。
      # 代理域名由节点解析。
      direct-nameserver = [
        "https://223.5.5.5/dns-query"
        "https://120.53.53.53/dns-query"
      ];

      # bootstrap 同样使用 IP 字面量 DoH，避免泄露端点域名。
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
      nameserver = baseConfig.dns.default-nameserver;
    };
  };

  yamlFormat = pkgs.formats.yaml { };
  baseConfigYaml = yamlFormat.generate "base-config.yaml" baseConfig;
  # fallback 承担首装时的 LAN DNS，并在构建期用 mihomo -t 验证。
  fallbackConfigYaml =
    pkgs.runCommand "mihomo-fallback.yaml"
      {
        src = yamlFormat.generate "fallback.yaml" fallbackConfig;
        nativeBuildInputs = [ pkgs.mihomo ];
      }
      ''
        mihomo -t -f "$src" -d "$(mktemp -d)"
        cp "$src" "$out"
      '';

  subscribeScript = pkgs.writeShellScript "mihomo-subscribe" ''
    set -euo pipefail

    # 临时文件含节点凭据与 API secret，统一限制为 0600。
    umask 077

    if [ -z "''${CONFIG_URL:-}" ]; then
      echo "CONFIG_URL not set in ${envFile}"
      exit 0
    fi

    if [ -z "''${SECRET:-}" ]; then
      echo "SECRET not set in ${envFile}; required for external-controller API authentication"
      exit 1
    fi

    # 清理 SIGKILL 或断电留下的历史凭据临时文件。
    rm -f "${stateDir}"/.mihomo-config.*.yaml

    tmp="$(mktemp -p "${stateDir}" .mihomo-config.XXXXXX.yaml)"

    # root 运行 mihomo -t 必须用独立目录，否则 geo/cache 会写成 root 所有。
    # 软链已有 geo 避免重复下载；新机在临时目录验证。
    validateDir="$(mktemp -d)"
    for f in "${stateDir}"/*.dat "${stateDir}"/*.mmdb "${stateDir}"/*.metadb; do
      if [ -e "$f" ]; then ln -s "$f" "$validateDir/"; fi
    done

    cleanup() {
      rm -f "$tmp"
      rm -rf "$validateDir"
    }
    trap cleanup EXIT

    echo "Fetching subscription..."
    curl -fsSL --connect-timeout 30 --max-time 120 \
      --retry 3 --retry-delay 2 --retry-all-errors \
      -o "$tmp" "$CONFIG_URL"

    echo "Sanitizing subscription..."
    # 订阅是外部输入：删除所有监听/API/权限字段，包括不校验 secret 的 unix/pipe/DoH。
    # `*` 仅让 base 覆盖声明键；代理、规则和 dns.nameserver 仍来自订阅。
    yq -i '
      del(.routing-mark) |
      del(.tun) |
      del(.listeners) |
      del(.tunnels) |
      del(.port) |
      del(.socks-port) |
      del(.redir-port) |
      del(.mixed-port) |
      del(.tproxy-port) |
      del(.allow-lan) |
      del(.bind-address) |
      del(.lan-allowed-ips) |
      del(.lan-disallowed-ips) |
      del(.authentication) |
      del(.skip-auth-prefixes) |
      del(.external-controller) |
      del(.external-controller-tls) |
      del(.external-controller-unix) |
      del(.external-controller-pipe) |
      del(.external-doh-server) |
      del(.external-ui) |
      del(.external-ui-name) |
      del(.external-ui-url) |
      del(.tls) |
      del(.secret)
    ' "$tmp"

    yq -i '. * load("${baseConfigYaml}")' "$tmp"

    SECRET="$SECRET" yq -i '.secret = strenv(SECRET)' "$tmp"

    echo "Validating configuration..."
    if ! output=$(mihomo -t -f "$tmp" -d "$validateDir" 2>&1); then
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

    # -t 只校验静态配置；轮询 10 秒捕获 RestartSec=5s 的崩溃并触发回滚。
    wait_healthy() {
      for _ in $(seq 10); do
        systemctl is-active --quiet mihomo || return 1
        sleep 1
      done
      return 0
    }

    echo "Configuration updated; restarting mihomo"
    # 必须忽略 restart 返回值，否则 set -e 会跳过下方回滚。
    systemctl restart mihomo || true

    if wait_healthy; then
      exit 0
    fi

    echo "mihomo failed to start with new config"
    if [ ! -f "${configFile}.bak" ]; then
      echo "No previous configuration to roll back to"
      exit 1
    fi
    echo "Rolling back to previous configuration"
    install -m 0600 "${configFile}.bak" "${configFile}"
    systemctl restart mihomo || true
    if wait_healthy; then
      echo "Rolled back; mihomo running on previous configuration"
    else
      echo "Rollback failed too; mihomo is down"
    fi
    exit 1
  '';
in
{
  services.mihomo = {
    enable = true;
    inherit configFile;
    # 禁用运行时下载的 external-ui-url，改用 nixpkgs pin 的 zashboard。
    webui = pkgs.zashboard;
  };

  systemd.tmpfiles.rules = [
    "d /etc/mihomo 0750 root root -"
    # 含订阅 URL 与 API secret。
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
    # 校验与运行必须使用同一 mihomo 包。
    path = [
      pkgs.curl
      pkgs.yq-go
      config.services.mihomo.package
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = subscribeScript;
      EnvironmentFile = [ "-${envFile}" ];

      # root 解析外部 YAML，尽量收紧沙箱。
      ProtectSystem = "strict";
      ReadWritePaths = [ stateDir ];
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      NoNewPrivileges = true;
      SystemCallArchitectures = "native";
    };
  };

  systemd.timers.mihomo-subscribe = {
    description = "Periodic Mihomo subscription update";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Persistent 对单调 timer 无效；开机拉取由 service wantedBy 负责。
      OnUnitActiveSec = "6h";
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

    # 网关是单点，禁用 start limit 并持续重试。
    # 不 fail-open：明文绕过 GFW 比显式断网风险更高。
    startLimitIntervalSec = 0;

    serviceConfig = {
      Restart = "always";
      RestartSec = "5s";

      # TPROXY UDP 回程需 bind 原始目标特权端口；DynamicUser 必须有 NET_BIND_SERVICE。
      # 缺失时 QUIC/443、NTP/123 回包会因 EACCES 丢失。
      AmbientCapabilities = lib.mkForce [
        "CAP_NET_ADMIN"
        "CAP_NET_BIND_SERVICE"
      ];
      CapabilityBoundingSet = lib.mkForce [
        "CAP_NET_ADMIN"
        "CAP_NET_BIND_SERVICE"
      ];
      PrivateUsers = lib.mkForce false;

      # UDP DIRECT 的 Go route 查询需要 AF_NETLINK；缺失时 TCP 正常但 UDP 静默失败。
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
