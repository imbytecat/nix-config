{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  version = "0.7.0";

  # 预编译二进制来自 GitHub Releases（goreleaser 构建，tree-sitter 已静态链接）
  srcs = {
    "aarch64-darwin" = {
      url = "https://github.com/code-yeongyu/go-claude-code-comment-checker/releases/download/v${version}/comment-checker_v${version}_darwin_arm64.tar.gz";
      hash = "sha256-0woeTNx7MXraKsshJB7aTkpnfi9GQn9dJEy+/VUfDX8=";
    };
    "x86_64-linux" = {
      url = "https://github.com/code-yeongyu/go-claude-code-comment-checker/releases/download/v${version}/comment-checker_v${version}_linux_amd64.tar.gz";
      hash = "sha256-YLmHQc0bBqyyR9LXRt2k/xWZLpHjna0twNsBbr1lVkY=";
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

  meta = with lib; {
    description = "Multi-language comment detection hook for Claude Code / OpenCode";
    homepage = "https://github.com/code-yeongyu/go-claude-code-comment-checker";
    license = licenses.mit;
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
    mainProgram = "comment-checker";
  };
}
