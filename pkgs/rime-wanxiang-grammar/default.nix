# 万象拼音 LTS 语法模型（整句/长句预测的核心，是万象比 rime-ice 强的最大来源）。
# 上游把它当作 release 资源覆盖式更新同一个 tag（见 RIME-LMDG#22），破坏可复现性，
# 故 nixpkgs 的 rime-wanxiang 刻意不含此文件（见其 longDescription）。这里自己 fetchurl
# 并 pin hash：随 rimeDataPkgs 一起合进 fcitx5-rime 只读共享目录，octagram 的
# FallbackResourceResolver 找不到用户目录版本时回落到共享目录即可加载（librime service.cc）。
# 上游哪天覆盖发布导致 hash 失配、构建报错，重新跑 nix store prefetch-file 取新 hash 即可。
{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation {
  pname = "rime-wanxiang-grammar";
  version = "LTS"; # 上游覆盖式发布，无稳定版本号；hash pin 于 2026-07（如失配即重新 prefetch）

  src = fetchurl {
    url = "https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram";
    hash = "sha256-Ij+OfaQGjp2jmrYzNwNnZRlAxFSACuQ9RsM0ubBZwok=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 $src $out/share/rime-data/wanxiang-lts-zh-hans.gram
    runHook postInstall
  '';

  meta = {
    description = "Wanxiang LTS grammar model for Rime (wanxiang-lts-zh-hans.gram)";
    homepage = "https://github.com/amzxyz/RIME-LMDG";
    license = lib.licenses.cc-by-40;
    platforms = lib.platforms.all;
  };
}
