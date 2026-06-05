{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  version = "0.8.0";

  # GitHub Releases 预编译二进制（goreleaser 构建，tree-sitter 静态链接）
  srcs = {
    "aarch64-darwin" = {
      url = "https://github.com/code-yeongyu/go-claude-code-comment-checker/releases/download/v${version}/comment-checker_v${version}_darwin_arm64.tar.gz";
      hash = "sha256-rHO3bx7PlhXoWaCnoA528lMFVj+Hp+4WjN0udsjjhVo=";
    };
    "x86_64-linux" = {
      url = "https://github.com/code-yeongyu/go-claude-code-comment-checker/releases/download/v${version}/comment-checker_v${version}_linux_amd64.tar.gz";
      hash = "sha256-D/Am/iRKoK+VZ9U7BGHJer9aUPhs4c61Ux/VQZSX3U8=";
    };
  };

  platformSrc =
    srcs.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "comment-checker";
  inherit version;

  src = fetchurl {
    inherit (platformSrc) url hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  unpackPhase = ''
    tar -xzf $src
  '';

  installPhase = ''
    install -Dm755 comment-checker $out/bin/comment-checker
  '';

  meta = {
    description = "Multi-language comment detection hook for Claude Code / OpenCode";
    homepage = "https://github.com/code-yeongyu/go-claude-code-comment-checker";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
    mainProgram = "comment-checker";
  };
}
