{ lib, ... }:

{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;

    settings = {
      add_newline = false;

      format = lib.concatStrings [
        "[░▒▓](#a3aed2)"
        "$os"
        "[](bg:#769ff0 fg:#a3aed2)"
        "$directory"
        "[](fg:#769ff0 bg:#394260)"
        "$git_branch"
        "$git_status"
        "[](fg:#394260 bg:#212736)"
        "$nix_shell"
        "$nodejs"
        "$python"
        "$go"
        "$rust"
        "$docker_context"
        "[](fg:#212736 bg:#1d2230)"
        "$cmd_duration"
        "[ ](fg:#1d2230)"
        "\n$character"
      ];

      character = {
        success_symbol = "[❯](bold #769ff0)";
        error_symbol = "[❯](bold red)";
      };

      os = {
        disabled = false;
        style = "bg:#a3aed2 fg:#090c0c";
        format = "[ $symbol]($style)";
        symbols = {
          NixOS = " ";
          Linux = " ";
          Macos = " ";
          Windows = "󰖳 ";
        };
      };

      directory = {
        style = "fg:#e3e5e5 bg:#769ff0";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
        substitutions = {
          Developer = " ";
          Documents = "󰈙 ";
          Downloads = " ";
        };
      };

      git_branch = {
        symbol = "";
        style = "bg:#394260";
        format = "[[ $symbol $branch ](fg:#769ff0 bg:#394260)]($style)";
      };

      git_status = {
        style = "bg:#394260";
        format = "[[($all_status$ahead_behind )](fg:#769ff0 bg:#394260)]($style)";
      };

      nix_shell = {
        symbol = " ";
        style = "bg:#212736";
        format = "[[ $symbol$state( \\($name\\)) ](fg:#769ff0 bg:#212736)]($style)";
      };

      nodejs = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
        detect_extensions = [ ];
      };

      python = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
      };

      go = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
      };

      rust = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
      };

      docker_context = {
        symbol = " ";
        style = "bg:#212736";
        format = "[[ $symbol $context ](fg:#769ff0 bg:#212736)]($style)";
      };

      cmd_duration = {
        min_time = 2000;
        style = "bg:#1d2230";
        format = "[[  $duration ](fg:#a0a9cb bg:#1d2230)]($style)";
      };
    };
  };
}
