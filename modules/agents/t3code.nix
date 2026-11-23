{ inputs, ... }:
let
  port = 3773;

  # 默认 wrapper 把 llm-agents 自带的 codex、claude-code 等前置进 PATH，会盖过 HM 的版本。
  t3codeFor =
    pkgs:
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.t3code.override {
      providerPackages = [ ];
    };

  # Nix 构建以未打包形式运行 Electron，不会自更新。
  desktop =
    { pkgs, ... }:
    {
      environment.systemPackages = [ (t3codeFor pkgs).desktop ];
    };
in
{
  # 桌面端在 Settings → Sharing & access 开 Network access 后监听全部地址（默认 3773），NixOS 只在 tailscale0 放行。
  aspects.nixos.daily.networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];

  aspects.nixos.desktop = desktop;
  aspects.darwin.desktop = desktop;

  aspects.homeManager.daily =
    { pkgs, ... }:
    {
      # 不开 server：桌面端要独占 ~/.t3 起自己的服务器，后台服务占着时它报错退出。
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
      };

      # 免费的开关就关上：它同时停掉产品事件与 relay trace，桌面端经 `zsh -ilc` 也读到它。
      home.sessionVariables.T3CODE_TELEMETRY_ENABLED = "false";
    };
}
