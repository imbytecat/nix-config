# 真 Windows 10 中文/西文具名字体，让 WPS 打开别人的文档按具名字体渲染不串版；思源/更纱只能
# 兜底、对不上名字。非自由字体，仅本地办公显示（不商用）。两个上游互补：base(streetsamurai00mi)
# 全套西文 + 宋体 + 微软雅黑，缺 SimHei/KaiTi/FangSong/DengXian；supplement(chillcicada) 补这四族。
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
