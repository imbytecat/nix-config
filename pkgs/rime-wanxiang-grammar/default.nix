# 上游覆盖发布同一 LTS tag，nixpkgs 因不可复现不打包；此处 pin hash。
# 安装到共享 rime-data；hash 失配时重新运行 `nix store prefetch-file`。
{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation {
  pname = "rime-wanxiang-grammar";
  version = "LTS"; # 上游无稳定版本号

  src = fetchurl {
    url = "https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram";
    hash = "sha256-mdab7x5ErrKP9+6Eg5ClfFoQTTsdH0gns+jRR14aCvU=";
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
