# Orca ADE（onorca.dev）：AppImage 二进制重打包。nixpkgs 的 orca 是 GNOME 屏幕阅读器，
# llm-agents.nix 也不收录，故自建；pname 跟随 AppImage 内部命名 orca-ide 避开冲突。
# 升级：改 version 后 `nix store prefetch-file <url>` 取新 hash。应用内 auto-updater
# 对只读 store 无效，属预期。
{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "orca-ide";
  version = "1.4.159";

  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
    hash = "sha256-GaK6tQqn1lydFrnl6F6JJC3+fkN+wxA4Z0lE58HuAQs=";
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/orca-ide.desktop $out/share/applications/orca-ide.desktop
    install -Dm444 ${appimageContents}/usr/share/icons/hicolor/512x512/apps/orca-ide.png \
      $out/share/icons/hicolor/512x512/apps/orca-ide.png
    # 上游 Categories=Utility 把 IDE 扔进「工具」，改到「开发」
    substituteInPlace $out/share/applications/orca-ide.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=orca-ide %U' \
      --replace-fail 'Categories=Utility;' 'Categories=Development;IDE;'
  '';

  meta = {
    description = "Agent Development Environment (ADE) for running CLI coding agents in parallel worktrees";
    homepage = "https://www.onorca.dev";
    downloadPage = "https://github.com/stablyai/orca/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "orca-ide";
  };
}
