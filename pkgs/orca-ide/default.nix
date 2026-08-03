# nixpkgs 的 orca 是 GNOME 屏幕阅读器、llm-agents.nix 亦不收录，故自建 AppImage 重打包；
# pname 跟随 AppImage 内部命名 orca-ide 避开冲突。升级：改 version 后
# `nix store prefetch-file <url>` 取新 hash；应用内 auto-updater 对只读 store 无效，属预期。
#
# 不用 appimageTools.wrapType2（= buildFHSEnv = bwrap）：IDE 里开的终端和 CLI agent 会继承
# 那个 user namespace，而 bwrap 只映射当前 uid，uid 0 未映射 → 整个 /nix/store 显示成
# nobody:nogroup，OpenSSH 的 owner 检查（readconf.c 只认 getuid() 或 0）直接拒绝
# ~/.ssh/config，git push 全挂；sudo 也因 PR_SET_NO_NEW_PRIVS 不可用。
# 改用 nixpkgs 对同类 Electron IDE 的做法（pkgs/by-name/co/code-cursor → buildVscode）：
# extract + autoPatchelfHook 原生跑，不进 namespace。
{
  lib,
  stdenv,
  appimageTools,
  fetchurl,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libayatana-appindicator,
  libgbm,
  libglvnd,
  libnotify,
  libpulseaudio,
  libsecret,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  nspr,
  nss,
  pango,
  pipewire,
  systemdLibs,
  wayland,
}:

let
  pname = "orca-ide";
  version = "1.4.165";

  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
    hash = "sha256-bUfsREvJIArWRdM5n3MIffjec5Zd99HU0AQUKmZJj8s=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
stdenv.mkDerivation {
  inherit pname version;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  strictDeps = true;

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
    makeWrapper
    wrapGAppsHook3
  ];

  # DT_NEEDED 实测集合（patchelf --print-needed 扫全部 24 个 ELF）：主二进制、
  # chrome_crashpad_handler、bundled ANGLE/swiftshader、node-pty、@parcel/watcher、sherpa-onnx。
  buildInputs = [
    (lib.getLib stdenv.cc.cc) # libstdc++.so.6 / libgcc_s.so.1，给 *.node 与 sherpa-onnx
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libgbm
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
    systemdLibs
  ];

  # dlopen 的部分不在 DT_NEEDED 里，靠 autoPatchelfHook 追加 RUNPATH（dlopen 认调用者的 RUNPATH）：
  # GL/EGL 交给 libglvnd；托盘图标（resources/tray/）走 GTK3 的 ayatana appindicator；
  # 通知声（resources/notification-sounds/）走 pulse；computer-use 截屏走 pipewire；
  # safeStorage 走 libsecret；ozone wayland 走 libwayland-client。
  runtimeDependencies = [
    libayatana-appindicator
    libglvnd
    libnotify
    libpulseaudio
    libsecret
    pipewire
    wayland
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/${pname}"
    # 保留 store 里的执行位（Electron 主程序、chrome_crashpad_handler、CLI 脚本都要），
    # 只补上属主写权限让 autoPatchelf/strip 能改。
    cp -r "${appimageContents}"/. "$out/lib/${pname}"
    chmod -R u+w "$out/lib/${pname}"

    # AppRun 与 usr/ 只服务 AppImage 自身的 FHS 假象：usr/lib 里那套 GTK2 时代的
    # libappindicator/libgconf/libindicator/libnotify/libXss/libXtst 仅靠 AppRun 的
    # LD_LIBRARY_PATH 生效，Electron 只 dlopen GTK3 版；留着只会把 gtk2 与 dbus-glib
    # 拖进闭包。图标先取出来再删。
    install -Dm444 "${appimageContents}/usr/share/icons/hicolor/512x512/apps/${pname}.png" \
      "$out/share/icons/hicolor/512x512/apps/${pname}.png"
    rm -r "$out/lib/${pname}"/{AppRun,.DirIcon,${pname}.png,${pname}.desktop,usr}

    # 外来架构预编译产物，autoPatchelf 无法满足 ld-linux-aarch64.so.1
    rm -r "$out/lib/${pname}/resources/node_modules/@parcel/watcher-linux-arm64-glibc"

    # node-gyp 中间产物：obj.target/pty.node 与 Release/pty.node 完全相同（md5 一致），
    # 同目录的 pty.o 还会让 shrink-rpath 报 "wrong ELF type"。
    rm -r "$out/lib/${pname}/resources/node_modules/node-pty/build/Release/obj.target"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = pname;
      desktopName = "Orca";
      comment = "Next-gen IDE for parallel agentic development";
      exec = "${pname} %U";
      icon = pname;
      startupNotify = true;
      startupWMClass = "orca";
      categories = [
        "Development"
        "IDE"
      ];
    })
  ];

  # wrapGAppsHook3 只用来产出 gappsWrapperArgs（GSETTINGS_SCHEMA_DIR、
  # GDK_PIXBUF_MODULE_FILE），包装动作自己做，避免它去包 $out/bin 里不存在的东西。
  dontWrapGApps = true;

  postFixup = ''
    makeWrapper "$out/lib/${pname}/${pname}" "$out/bin/${pname}" \
      "''${gappsWrapperArgs[@]}" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}}"
  '';

  meta = {
    description = "Agent Development Environment (ADE) for running CLI coding agents in parallel worktrees";
    homepage = "https://www.onorca.dev";
    downloadPage = "https://github.com/stablyai/orca/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
