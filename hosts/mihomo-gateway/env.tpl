# 只含 op:// 引用，无真实密钥，可安全进 git（同 home/shell/fish.nix 的 op-env 约定）。
# 由 `just gateway-env <remote>` 用 op inject 渲染后推到网关 /etc/mihomo/env，
# systemd.paths 监听到变化会自动重新拉取订阅。
# 首次使用前把下面两个 op:// 引用改成你 1Password 里真实的 vault/item/field。
CONFIG_URL={{ op://Developer/Mihomo Gateway/subscription }}
SECRET={{ op://Developer/Mihomo Gateway/credential }}
