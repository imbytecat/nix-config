{
  lib,
  osConfig,
  config,
  pkgs,
  ...
}:

let
  # 四份 custom 必须使用同一双拼名，否则附属方案仍按全拼查表。
  shuangpin = "小鹤双拼";

  # nix store mtime 恒为 1970，Rime 会漏掉配置变化；删除 build 强制重编译。
  # 无用户 D-Bus 时在线部署可失败，fcitx5 下次启动会重建。
  redeployRime = ''
    rm -rf "${config.xdg.dataHome}/fcitx5/rime/build"
    ${pkgs.systemd}/bin/busctl --user call org.fcitx.Fcitx5 /controller \
      org.fcitx.Fcitx.Controller1 SetConfig sv "fcitx://config/addon/rime/deploy" s "" || true
  '';
in
lib.mkIf osConfig.i18n.inputMethod.enable {
  xdg.dataFile."fcitx5/rime/default.custom.yaml" = {
    text = ''
      patch:
        __include: wanxiang_suggested_default:/
        # Shift 仅由 fcitx5 组切换处理
        ascii_composer/switch_key/Shift_L: noop
    '';
    onChange = redeployRime;
  };

  # 官方 /flypy 会同时写四份 custom；这里只能声明式复制其四份双拼 patch。
  # HM 文件是只读 symlink，且 nixpkgs 已删除 /flypy 依赖的 custom 模板。
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

  xdg.dataFile."fcitx5/rime/wanxiang_reverse.custom.yaml" = {
    text = ''
      patch:
        speller/algebra:
          __include: wanxiang_algebra:/reverse/${shuangpin}
          __patch: wanxiang_algebra:/reverse/hspzn
    '';
    onChange = redeployRime;
  };

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

  # Hangul 由 CapsLock 映射触发；显式移除默认 Ctrl+Space。
  xdg.configFile."fcitx5/config".text = lib.generators.toINI { } {
    "Hotkey/TriggerKeys"."0" = "Hangul";
    # 禁用默认 Shift_L 临时切换，避免单击 Shift 误切中英
    "Hotkey/AltTriggerKeys"."0" = "";
  };
}
