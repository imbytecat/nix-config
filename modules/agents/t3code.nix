{ inputs, ... }:
let
  port = 3773;

  # 默认 wrapper 把 llm-agents 自带的 codex、claude-code 等前置进 PATH，会盖过 HM 的版本。
  t3codeFor =
    pkgs:
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.t3code.override {
      providerPackages = [ ];
    };

  # 遥测默认开。managed policy 同时管服务与桌面端，从 Dock 启动的桌面端读不到 shell 变量也生效。
  policy = builtins.toJSON { limits.telemetry = false; };

  # Nix 构建以未打包形式运行 Electron，不会自更新。
  desktop =
    { pkgs, ... }:
    {
      environment.systemPackages = [ (t3codeFor pkgs).desktop ];
    };
in
{
  # --lan 监听全部地址：NixOS 防火墙只在 tailscale0 放行；用户服务开 linger，重启后不登录也起来。
  aspects.nixos.daily =
    { username, ... }:
    {
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];
      users.users.${username}.linger = true;
      environment.etc."t3code/policy.json".text = policy;
    };

  aspects.darwin.daily =
    { pkgs, ... }:
    {
      system.activationScripts.postActivation.text = ''
        mkdir -p "/Library/Application Support/T3Code"
        install -m 0644 ${pkgs.writeText "t3code-policy.json" policy} "/Library/Application Support/T3Code/policy.json"
      '';
    };

  aspects.nixos.desktop = desktop;
  aspects.darwin.desktop = desktop;

  aspects.homeManager.daily =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # 遥测默认开，交互 shell 里的 `t3` CLI 与服务都要关。
      telemetryOff = {
        T3CODE_TELEMETRY_ENABLED = "false";
        T3CODE_OTEL_SDK_DISABLED = "true";
      };
      # 服务不经 login shell，补上终端里的 PATH，T3 与它起的 agent 才找得到 omp、codex、git。
      serviceEnv = telemetryOff // {
        DO_NOT_TRACK = "1";
        PATH = lib.concatStringsSep ":" (
          map (lib.replaceStrings [ "$HOME" ] [ config.home.homeDirectory ]) config.home.sessionPath
          ++ [
            "${config.home.profileDirectory}/bin"
            "/run/wrappers/bin"
            "/run/current-system/sw/bin"
            "/nix/var/nix/profiles/default/bin"
            "/usr/local/bin"
            "/usr/bin"
            "/bin"
            "/usr/sbin"
            "/sbin"
          ]
        );
      };
    in
    {
      programs.t3code = {
        enable = true;
        package = t3codeFor pkgs;
        # 命令名必须是 omp，T3 才对它套用 omp 专用的提问表单解析。
        userSettings.providerInstances.omp = {
          driver = "acpRegistry";
          displayName = "Oh My Pi";
          config = {
            source = "local";
            commandPath = "omp";
            commandArgs = [ "acp" ];
          };
        };
        # 不登录 T3 Connect：手机用 `t3 pair` 配对后经 tailnet 直连，配对 token 是唯一门槛。
        server = {
          enable = true;
          extraArgs = [
            "--lan"
            "--port"
            (toString port)
            config.home.homeDirectory
          ];
          environmentFile = "${config.xdg.cacheHome}/op-env/env";
        };
      };

      home.sessionVariables = telemetryOff;

      launchd.agents.t3code.config = {
        EnvironmentVariables = serviceEnv;
        # 模块默认 Background 会被 macOS 限流；agent 在里面跑，照 `t3 service install` 用 Interactive。
        ProcessType = lib.mkForce "Interactive";
      };
      systemd.user.services.t3code.Service.Environment = lib.mapAttrsToList (
        name: value: "${name}=${value}"
      ) serviceEnv;
    };
}
