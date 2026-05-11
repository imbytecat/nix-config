{
  pkgs,
  lib,
  config,
  ...
}:

let
  playwrightMcpCache = "${config.xdg.cacheHome}/ms-playwright";
in

{
  config = lib.mkIf pkgs.stdenv.isLinux {
    home.packages = [ pkgs.chromium ];

    home.sessionVariables = {
      PLAYWRIGHT_MCP_BROWSER = "chromium";
      PLAYWRIGHT_MCP_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
      PLAYWRIGHT_MCP_OUTPUT_DIR = "${playwrightMcpCache}/mcp-output";
      PLAYWRIGHT_MCP_USER_DATA_DIR = "${playwrightMcpCache}/mcp-chromium-profile";
    };

    home.activation.createPlaywrightMcpDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${lib.escapeShellArg playwrightMcpCache}/mcp-output ${lib.escapeShellArg playwrightMcpCache}/mcp-chromium-profile
    '';
  };
}
