# 跨 DE 的 fcitx5/rime home 配置（换 GNOME/Hyprland/niri 也照用；与 plasma.nix 的 Plasma 专属
# KWin InputMethod 互补、二者都要，详见 docs/adr/0003-wayland-ime-fcitx.md）。按
# osConfig.i18n.inputMethod.enable 收窄——系统真开输入法才写，与 plasma.nix 同纪律，无头机不落多余 dotfile。
{
  lib,
  osConfig,
  config,
  pkgs,
  ...
}:

let
  # librime 靠 mtime 判断是否需要重编译，而 nix store 文件 mtime 恒为 1970——patch 变了 rime
  # 也认为"没变化"永远跳过重编译。删 build/ 强制重编，再尽力触发在线部署；D-Bus 不可用（如系统
  # 激活时无会话）也无妨，fcitx5 下次启动自会重建。多个 rime 配置文件（default + wanxiang.*）共用此钩子。
  redeployRime = ''
    rm -rf "${config.xdg.dataHome}/fcitx5/rime/build"
    ${pkgs.systemd}/bin/busctl --user call org.fcitx.Fcitx5 /controller \
      org.fcitx.Fcitx.Controller1 SetConfig sv "fcitx://config/addon/rime/deploy" s "" || true
  '';
in
lib.mkIf osConfig.i18n.inputMethod.enable {
  # 万象拼音需用户侧 default.custom.yaml __include 才成型（见 docs/adr/0003-wayland-ime-fcitx.md）。
  # 后续 Rime 全局自定义（候选数、按键等）也加在这份 patch 里。
  xdg.dataFile."fcitx5/rime/default.custom.yaml" = {
    text = ''
      patch:
        __include: wanxiang_suggested_default:/
        # 关掉 rime 内部 Shift 切 ascii_mode——中英状态只留 fcitx5 组切换（CapsLock）一个入口
        ascii_composer/switch_key/Shift_L: noop
    '';
    onChange = redeployRime;
  };

  # 万象主方案默认全拼；下面四个 custom 把主方案 + 反查/中英混输/英文的辅助码全部定死小鹤双拼，
  # 等价于官方 /flypy 斜杠指令重部署的结果。nixpkgs 打包时 rm 掉了 custom/ 模板（/flypy 靠拷贝它
  # 生成用户文件），故这里按上游模板声明式写死（英文/混输方案默认不在 schema_list，写了也只是备着）。
  xdg.dataFile."fcitx5/rime/wanxiang.custom.yaml" = {
    text = ''
      patch:
        speller/algebra:
          __patch:
            - wanxiang_algebra:/base/小鹤双拼
    '';
    onChange = redeployRime;
  };
  xdg.dataFile."fcitx5/rime/wanxiang_reverse.custom.yaml" = {
    text = ''
      patch:
        speller/algebra:
          __include: wanxiang_algebra:/reverse/小鹤双拼
          __patch: wanxiang_algebra:/reverse/hspzn
    '';
    onChange = redeployRime;
  };
  xdg.dataFile."fcitx5/rime/wanxiang_mixedcode.custom.yaml" = {
    text = ''
      patch:
        speller/algebra:
          __include: wanxiang_algebra:/mixed/通用派生规则
          __patch: wanxiang_algebra:/mixed/小鹤双拼
    '';
    onChange = redeployRime;
  };
  xdg.dataFile."fcitx5/rime/wanxiang_english.custom.yaml" = {
    text = ''
      patch:
        speller/algebra:
          __include: wanxiang_algebra:/english/通用规则
          __patch: wanxiang_algebra:/english/小鹤双拼
    '';
    onChange = redeployRime;
  };

  # fcitx5 输入法组：默认 IM=rime；home-manager 每 switch 覆盖 ~/.config/fcitx5/profile，新装即成型。
  # 为何走用户路径而非 NixOS ignoreUserConfig，见 docs/adr/0003-wayland-ime-fcitx.md。
  xdg.configFile."fcitx5/profile".text = lib.generators.toINI { } {
    GroupOrder."0" = "Default";
    "Groups/0" = {
      Name = "Default";
      "Default Layout" = "us";
      DefaultIM = "rime";
    };
    "Groups/0/Items/0".Name = "keyboard-us";
    "Groups/0/Items/1".Name = "rime";
  };

  # 触发键只绑 Hangul（CapsLock 经 keyd 重映射而来，见 modules/desktop/nixos.nix），
  # 显式覆盖默认的 Ctrl+Space——把它还给应用（VS Code 补全等）。文件被 HM 管成只读
  # symlink 后 fcitx5 GUI 改不了全局热键，与 profile 同纪律。
  xdg.configFile."fcitx5/config".text = lib.generators.toINI { } {
    "Hotkey/TriggerKeys"."0" = "Hangul";
    # fcitx5 自身默认 AltTriggerKeys=Shift_L（临时切换 IM），与 rime 内部 Shift 切换叠加；
    # 置空，杜绝单击 Shift 误切中英
    "Hotkey/AltTriggerKeys"."0" = "";
  };
}
