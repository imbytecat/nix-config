{
  # SDK 里的 emulator 经 nix-ld 找库；列表与模块默认库合并，桌面机同时拿到两份。
  aspects.nixos.daily =
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
}
