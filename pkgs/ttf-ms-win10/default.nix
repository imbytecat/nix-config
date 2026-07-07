# WPS/Office 文档按具名字体渲染（宋体/黑体/楷体/仿宋/微软雅黑/等线 + Calibri/Times New Roman
# 等），思源/更纱只能兜底、对不上名字，别人发来的文档会串版。这里装真 Windows 10 字体补齐。
# 非自由字体，仅本地办公显示用途（用户已确认不商用）。
#
# 两个上游互补：base(streetsamurai00mi) 有全套西文（含 corefonts 都没有的 Calibri/Cambria）
# + 宋体 simsun + 微软雅黑 msyh + 繁体 + Webdings/Wingdings/Symbol，但缺 SimHei/KaiTi/FangSong/
# DengXian；chillcicada 的补充包正好只补这四族。base 的 hash 复用 NUR rewine 的固定 rev。
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

let
  base = fetchFromGitHub {
    owner = "streetsamurai00mi";
    repo = "ttf-ms-win10";
    rev = "417eb232e8d037964971ae2690560a7b12e5f0d4";
    hash = "sha256-UwkHlrSRaXhfoMlimyXFETV9yq1SbvUXykrhigf+wP8=";
  };
  supplement = fetchFromGitHub {
    owner = "chillcicada";
    repo = "ttf-ms-win10-sc-sup";
    rev = "f5d2ef2c84e8979b322563a53ea3adb5ab995176";
    hash = "sha256-gIMRE1jOEtskRzXGdUr6DRXghpMdM37NtoEJsC80/MQ=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "ttf-ms-win10";
  version = "unstable-2021-02-10";

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 -t $out/share/fonts/truetype ${base}/*.ttf ${base}/*.ttc
    install -Dm644 -t $out/share/fonts/truetype ${supplement}/*.ttf
    runHook postInstall
  '';

  meta = {
    description = "Microsoft Windows 10 TrueType fonts (Simplified Chinese + Western) for WPS/Office fidelity";
    homepage = "https://github.com/streetsamurai00mi/ttf-ms-win10";
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}
