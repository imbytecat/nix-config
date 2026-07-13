{
  pkgs,
  lib,
  config,
  inputs,
  system,
  ...
}:

let
  playwrightMcpCache = "${config.xdg.cacheHome}/ms-playwright";
in
{
  # AI agent 驱动的浏览器工具，都指向 nix chromium。
  # agent-browser：nix 包 wrapper 已自带 env，开箱即用（跨平台）。
  # playwright：npm 装的，得手工用 PLAYWRIGHT_MCP_* 指向 nix chromium，仅 Linux。
  home.packages = [
    inputs.llm-agents.packages.${system}.agent-browser
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.chromium ];

  home.sessionVariables = lib.mkIf pkgs.stdenv.isLinux {
    PLAYWRIGHT_MCP_BROWSER = "chromium";
    PLAYWRIGHT_MCP_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
    PLAYWRIGHT_MCP_OUTPUT_DIR = "${playwrightMcpCache}/mcp-output";
    PLAYWRIGHT_MCP_USER_DATA_DIR = "${playwrightMcpCache}/mcp-chromium-profile";
  };

  home.activation.createPlaywrightMcpDirs = lib.mkIf pkgs.stdenv.isLinux (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${lib.escapeShellArg playwrightMcpCache}/mcp-output ${lib.escapeShellArg playwrightMcpCache}/mcp-chromium-profile
    ''
  );
}
