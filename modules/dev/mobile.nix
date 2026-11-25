{
  # SDK 留在 store 外的可写目录：AGP 和 Flutter 会往 SDK 根目录自动下载 NDK 与 platform。
  # Android CLI、Flutter 由各项目的 mise 固定版本，这里只装项目外也要用的部分。
  aspects.homeManager.workstation =
    { pkgs, ... }:
    {
      # adb 与 fastboot；systemd 258 的 uaccess 已管设备权限，无需 adbusers 或 udev 规则。
      home.packages = [ pkgs.android-tools ];

      home.sessionVariables = {
        ANDROID_HOME =
          if pkgs.stdenv.hostPlatform.isDarwin then "$HOME/Library/Android/sdk" else "$HOME/Android/Sdk";
        # Flutter 遥测默认开启；它自己的开关在工具会改写的 ~/.dart-tool 状态文件里，不能交给 HM。
        FLUTTER_SUPPRESS_ANALYTICS = "true";
      };

      # Android CLI 遥测默认开启；.androidrc 的全局 flag 对每次调用生效。
      home.file.".androidrc".text = "--no-metrics\n";
    };

  # SDK 里的 emulator 经 nix-ld 找库；列表与模块默认库合并，桌面机同时拿到两份。
  aspects.nixos.workstation =
    { pkgs, ... }:
    {
      # 启动器和 -headless qemu 都链接 libX11.so.6，-no-window 也要。
      # Linux 的 -gpu host 走 GLX、需要 X 显示，无头只能用 SwiftShader。
      programs.nix-ld.libraries = [ pkgs.libx11 ];
    };

  aspects.nixos.desktop =
    { pkgs, ... }:
    {
      # 带窗口：窗口版 qemu 的 PulseAudio、Qt xcb 和 WebEngine 的 NSS，-gpu host 经 libglvnd 用 Mesa。
      # libtiff.so.5 没有对应包（nixpkgs 是 .so.6），只影响 Qt 的 TIFF 图片插件。
      programs.nix-ld.libraries = with pkgs; [
        dbus
        expat
        libbsd
        libdrm
        libgbm
        libglvnd
        libice
        libpng
        libpulseaudio
        libsm
        libxcb
        libxext
        libxi
        libxkbfile
        nspr
        nss
      ];
    };

  aspects.darwin.workstation.homebrew.brews = [ "cocoapods" ];
  aspects.darwin.desktop.homebrew.casks = [ "xcodes-app" ];
}
