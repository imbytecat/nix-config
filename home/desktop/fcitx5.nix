# 跨 DE 的 fcitx5/rime home 配置（换 GNOME/Hyprland/niri 也照用；与 plasma.nix 的 Plasma 专属
# KWin InputMethod 互补、二者都要）。按
# osConfig.i18n.inputMethod.enable 收窄——系统真开输入法才写，与 plasma.nix 同纪律，无头机不落多余 dotfile。
{
  lib,
  osConfig,
  config,
  pkgs,
  ...
}:

let
  # 双拼方案名，取值见 wanxiang_algebra.yaml 的 base / english / mixed / reverse 各节。
  # 四份 custom 必须同名，否则附属方案仍按全拼码查表。
  shuangpin = "小鹤双拼";

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
  # 万象拼音需用户侧 default.custom.yaml __include 才成型。
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

  # 万象主方案默认全拼。官方 /flypy 指令一次写四份 custom（见 lua/wanxiang/set_schema.lua）：
  # 主方案、英文、混输、反查——只改主方案会让英文混输和反查继续按全拼码查表。不走 /flypy：
  # home-manager 把 custom 管成只读 symlink 而 /flypy 要写它、且 nixpkgs 删了它依赖的 custom/ 模板。
  xdg.dataFile."fcitx5/rime/wanxiang.custom.yaml" = {
    text = ''
      patch:
        speller/algebra:
          __patch:
            - wanxiang_algebra:/base/${shuangpin}
    '';
    onChange = redeployRime;
  };

  xdg.dataFile."fcitx5/rime/wanxiang_english.custom.yaml" = {
    text = ''
      patch:
        speller/algebra:
          __include: wanxiang_algebra:/english/通用规则
          __patch: wanxiang_algebra:/english/${shuangpin}
    '';
    onChange = redeployRime;
  };

  xdg.dataFile."fcitx5/rime/wanxiang_mixedcode.custom.yaml" = {
    text = ''
      patch:
        speller/algebra:
          __include: wanxiang_algebra:/mixed/通用派生规则
          __patch: wanxiang_algebra:/mixed/${shuangpin}
    '';
    onChange = redeployRime;
  };

  # 反查的 __patch 是笔画类型（hspzn / hupvd / hslzy），与双拼方案名无关，保持默认。
  xdg.dataFile."fcitx5/rime/wanxiang_reverse.custom.yaml" = {
    text = ''
      patch:
        speller/algebra:
          __include: wanxiang_algebra:/reverse/${shuangpin}
          __patch: wanxiang_algebra:/reverse/hspzn
    '';
    onChange = redeployRime;
  };

  # fcitx5 输入法组：默认 IM=rime；home-manager 每 switch 覆盖 ~/.config/fcitx5/profile，新装即成型。
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
