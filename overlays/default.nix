final: _:
let
  # XWayland 下的 Qt5 应用需显式 *_IM_MODULE=fcitx 才能用 fcitx5。
  wrapWithFcitx =
    pkg: bins:
    final.symlinkJoin {
      name = "${final.lib.getName pkg}-fcitx5";
      paths = [ pkg ];
      nativeBuildInputs = [ final.makeWrapper ];
      postBuild = ''
        for bin in ${final.lib.concatStringsSep " " bins}; do
          wrapProgram $out/bin/$bin \
            --set QT_IM_MODULE fcitx \
            --set GTK_IM_MODULE fcitx \
            --set XMODIFIERS @im=fcitx
        done
      '';
    };
in
{
  ttf-ms-win10 = final.callPackage ../pkgs/ttf-ms-win10 { };

  wechat-fcitx = wrapWithFcitx final.wechat [ "wechat" ];
  wpsoffice-fcitx = wrapWithFcitx final.wpsoffice-cn [
    "wps"
    "et"
    "wpp"
    "wpspdf"
  ];
}
