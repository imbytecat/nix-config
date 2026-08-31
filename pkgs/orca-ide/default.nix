# 上游 orca 是屏幕阅读器；此处将 Orca IDE AppImage 原生重打包。
# 不用 wrapType2：bwrap user namespace 会令 SSH 配置显示为 nobody，git 与 sudo 失效。
# src 名称必须带 version；否则 fetchurl 会复用旧 store path，nix-update 无法发现 hash 变化。
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
  version = "1.4.193";

  src = fetchurl {
    name = "${pname}-${version}.AppImage";
    url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
    hash = "sha256-P4Fv8i+cM/nEoeUSzIgoXAEu6/bKqujOvr3ft56QCFU=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
stdenv.mkDerivation {
  inherit pname version src;

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

  # patchelf 扫描全部 24 个 ELF 得出的 DT_NEEDED 集合。
  buildInputs = [
    (lib.getLib stdenv.cc.cc) # *.node 与 sherpa-onnx
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

  # dlopen 依赖不在 DT_NEEDED：GL、托盘、通知、PipeWire、safeStorage、Wayland。
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
    # 保留执行位，只补属主写权限供 autoPatchelf/strip。
    cp -r "${appimageContents}"/. "$out/lib/${pname}"
    chmod -R u+w "$out/lib/${pname}"

    # AppRun/usr 仅构造 AppImage FHS；先复制图标再删，避免拖入 GTK2/dbus-glib。
    install -Dm444 "${appimageContents}/usr/share/icons/hicolor/512x512/apps/${pname}.png" \
      "$out/share/icons/hicolor/512x512/apps/${pname}.png"
    rm -r "$out/lib/${pname}"/{AppRun,.DirIcon,${pname}.png,${pname}.desktop,usr}

    # 删除与 Release/pty.node 重复且会让 shrink-rpath 报错的 node-gyp 中间产物。
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

  # 只取 gappsWrapperArgs；$out/bin 尚不存在，手动包装。
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
