{ pkgs, lib, ... }:

{
  # Playwright 走 Nix 提供的浏览器，跳过 npm 自下载和 Ubuntu 系统依赖校验。
  # 仅 Linux：macOS 走 Homebrew cask 装 chromium，Playwright 自管浏览器即可。
  # 系统级 chromium 用于日常浏览 / 手动复现；Playwright 自身用的是 playwright-driver.browsers 里 patch 过的 chromium
  config = lib.mkIf pkgs.stdenv.isLinux {
    home.packages = with pkgs; [
      chromium
      playwright-driver.browsers
    ];

    home.sessionVariables = {
      PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
      PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
    };
  };
}
