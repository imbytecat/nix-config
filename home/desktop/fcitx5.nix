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
  # switch 不重启 fcitx5：旧进程会按旧 rime-data 重建 build，只允许当前包的进程在线部署，
  # 否则留给下次启动（build 被删使目录 mtime 晚于 last_build_time，启动时自动部署）。
  redeployRime = ''
    rm -rf "${config.xdg.dataHome}/fcitx5/rime/build"
    if ${pkgs.procps}/bin/pgrep -u "$(id -u)" -f "^${osConfig.i18n.inputMethod.package}/bin/fcitx5" >/dev/null; then
      ${pkgs.systemd}/bin/busctl --user call org.fcitx.Fcitx5 /controller \
        org.fcitx.Fcitx.Controller1 SetConfig sv "fcitx://config/addon/rime/deploy" s "" || true
    fi
  '';
in
lib.mkIf osConfig.i18n.inputMethod.enable {
  xdg.dataFile."fcitx5/rime/default.custom.yaml" = {
    force = true;
    text = ''
      # 跟踪输入法包变化，避免升级后旧 build 引用已移除的 Lua 模块。
      # ${osConfig.i18n.inputMethod.package}
      patch:
        __include: wanxiang_suggested_default:/
        # Shift 仅由 fcitx5 组切换处理
        ascii_composer/switch_key/Shift_L: noop
    '';
    onChange = redeployRime;
  };

  # HM 文件是只读 symlink，不能使用 /flypy；这里声明四个拼音方案的双拼 patch。
  # 简码与自造词方案沿用上游 26jian，不需要双拼转写。
  xdg.dataFile."fcitx5/rime/wanxiang.custom.yaml" = {
    force = true;
    text = ''
      patch:
        speller/algebra:
          __patch:
            - wanxiang_algebra:/base/${shuangpin}
    '';
    onChange = redeployRime;
  };

  xdg.dataFile."fcitx5/rime/wanxiang_english.custom.yaml" = {
    force = true;
    text = ''
      patch:
        speller/algebra:
          __patch:
            - wanxiang_algebra:/english/混合派生
            - wanxiang_algebra:/english/${shuangpin}
    '';
    onChange = redeployRime;
  };

  xdg.dataFile."fcitx5/rime/wanxiang_mixedcode.custom.yaml" = {
    force = true;
    text = ''
      patch:
        speller/algebra:
          __patch:
            - wanxiang_algebra:/mixed/混合派生
            - wanxiang_algebra:/mixed/${shuangpin}
    '';
    onChange = redeployRime;
  };

  xdg.dataFile."fcitx5/rime/wanxiang_reverse.custom.yaml" = {
    force = true;
    text = ''
      patch:
        speller/algebra:
          __patch:
            - wanxiang_algebra:/reverse/${shuangpin}
            - wanxiang_algebra:/reverse/hspzn
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
