{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    escapeTime = 10;
    historyLimit = 50000;
    keyMode = "vi";
    mouse = true;
    terminal = "tmux-256color";
    prefix = "C-a";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      vim-tmux-navigator
      yank
    ];

    extraConfig = ''
      # ── True color support ──
      set -ag terminal-overrides ",xterm-256color:RGB"

      # ── Split panes ──
      bind v split-window -h -c "#{pane_current_path}"
      bind s split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %

      # ── New window in current path ──
      bind c new-window -c "#{pane_current_path}"

      # ── Reload config ──
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

      # ── Resize panes ──
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # ── Status bar ──
      set -g status-position top
      set -g renumber-windows on

      # ── Copy mode vim bindings ──
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel
    '';
  };
}
