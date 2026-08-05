# Windows 10 具名字体保证 WPS/Office 文档不串版；非自由，仅本地显示。
# base 缺 SimHei/KaiTi/FangSong/DengXian，supplement 补齐。
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
