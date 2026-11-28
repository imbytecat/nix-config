{ inputs, ... }:
let
  port = 3773;

  # 默认 wrapper 把 llm-agents 自带的 codex、claude-code 等前置进 PATH，会盖过 HM 的版本。
  t3codeFor =
    pkgs:
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.t3code.override {
      providerPackages = [ ];
    };

  # T3 Connect 的中继隧道；每台机器手动 `t3 connect link` 授权。
  cloudflared =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.cloudflared ];
    };

  # Nix 构建以未打包形式运行 Electron，不会自更新。
  desktop =
    { pkgs, ... }:
    {
      environment.systemPackages = [ (t3codeFor pkgs).desktop ];
    };
in
{
  aspects.darwin.workstation = cloudflared;
  aspects.nixos.workstation =
    { username, ... }:
    {
      imports = [ cloudflared ];

      # 用户服务开 linger，重启后不登录也起来。
      users.users.${username}.linger = true;

      # 用户服务读不到 system 级 restartUnits；已登录的会话在解密成功后重新载入 dotenv。
      systemd.services.sops-install-secrets.postStart = ''
        uid=$(id -u ${username})
        if [ -S "/run/user/$uid/bus" ] && systemctl --user --machine=${username}@.host cat t3code.service >/dev/null 2>&1; then
          systemctl --user --machine=${username}@.host --no-block restart t3code.service
        fi
      '';
    };

  aspects.nixos.desktop = {
    imports = [ desktop ];
    # --lan 监听全部地址，NixOS 防火墙只在 tailscale0 放行。
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];
  };
  aspects.darwin.desktop = desktop;

  aspects.homeManager.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      programs.t3code.server.extraArgs = lib.mkBefore [ "--lan" ];

      # 服务占着 ~/.t3，桌面端的本地环境会抢同一把锁（弹 "This T3 home is unavailable" 后退出），只当客户端。
      home.activation.t3codeDesktopClient = lib.hm.dag.entryAfter [ "linkGeneration" ] (
        lib.hm.generators.mkImpureConfigMerger {
          inherit pkgs;
          format = "json";
          empty = "{}";
          jqOperation = "$dynamic * $static";
          path = "${config.home.homeDirectory}/.t3/userdata/desktop-settings.json";
          staticSettings = (pkgs.formats.json { }).generate "t3code-desktop-settings.json" {
            localEnvironmentEnabled = false;
          };
        }
      );
    };

  aspects.homeManager.workstation =
    {
      aiCatalog,
      config,
      lib,
      pkgs,
      sessionEnvFile,
      withSessionEnv,
      ...
    }:
    let
      # 遥测默认开，服务与交互 shell 里的 `t3` CLI 都要关。
      telemetryOff.T3CODE_TELEMETRY_ENABLED = "false";
      serviceEnv = telemetryOff // {
        PATH = import ./_service-path.nix lib config.home;
      };

      # Codex 的 TUI 和 app-server 都读原生登录文件。密钥经 stdin 传入。
      login = pkgs.writeShellApplication {
        name = "codex-api-login";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          printenv ${aiCatalog.gateway.apiKeyEnv} | ${lib.getExe config.programs.codex.package} login --with-api-key
        '';
      };
      launch = withSessionEnv "t3code-with-secrets" ''
        ${lib.getExe login}
        exec "$@"
      '';
    in
    {
      programs.t3code = {
        enable = true;
        package = t3codeFor pkgs;
        userSettings.defaultRuntimeMode = "full-access";
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
        server = {
          enable = true;
          extraArgs = [
            "--port"
            (toString port)
            config.home.homeDirectory
          ];
        };
      };

      home.sessionVariables = telemetryOff;

      launchd.agents.t3code.config = {
        ProgramArguments = lib.mkBefore [ launch ];
        EnvironmentVariables = serviceEnv;
        # 模块默认 Background 会被 macOS 限流；agent 在里面跑，照 `t3 service install` 用 Interactive。
        ProcessType = lib.mkForce "Interactive";
      };
      systemd.user.services.t3code = {
        Unit.ConditionPathExists = sessionEnvFile;
        Service = {
          Environment = lib.mapAttrsToList (name: value: "${name}=${value}") serviceEnv;
          EnvironmentFile = sessionEnvFile;
          ExecStartPre = lib.getExe login;
        };
      };
    };
}
