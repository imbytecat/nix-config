{
  lib,
  pkgs,
  ...
}:

{
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    dates = "weekly";
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    interval = {
      Weekday = 0;
      Hour = 3;
      Minute = 15;
    };
  };
}
