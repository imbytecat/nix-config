{ lib, ... }:

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      add_newline = false;

      format = lib.concatStrings [
        "$os"
        "$username"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_status"
        "$nix_shell"
        "$nodejs"
        "$python"
        "$go"
        "$rust"
        "$docker_context"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      os = {
        disabled = false;
        symbols = {
          NixOS = " ";
          Linux = " ";
          Macos = " ";
          Windows = "󰖳 ";
        };
      };

      directory = {
        truncation_length = 3;
        truncation_symbol = "…/";
        substitutions = {
          Developer = " ";
          Documents = "󰈙 ";
          Downloads = " ";
        };
      };

      git_branch.symbol = " ";

      git_status = {
        format = "([\\[$all_status$ahead_behind\\]]($style) )";
      };

      nix_shell = {
        symbol = " ";
        format = "[$symbol$state( \\($name\\))]($style) ";
      };

      docker_context = {
        symbol = " ";
        format = "[$symbol$context]($style) ";
      };

      cmd_duration = {
        min_time = 2000;
        format = "[$duration]($style) ";
      };

      nodejs = {
        format = "[$symbol($version)]($style) ";
        detect_extensions = [ ];
      };

      python.format = "[$symbol($version)]($style) ";
      go.format = "[$symbol($version)]($style) ";
      rust.format = "[$symbol($version)]($style) ";
    };
  };
}
