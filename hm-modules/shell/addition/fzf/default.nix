{ config, lib, pkgs, ... }:

with lib;

let cfg = config.dov.shell.addition.fzf;
in {
  options.dov.shell.addition.fzf.enable = mkEnableOption "fzf configuration";

  config = mkIf cfg.enable {
    programs.fzf = {
      enable = cfg.enable;
      enableZshIntegration = config.dov.shell.zsh.enable;
      tmux.enableShellIntegration = config.dov.shell.addition.tmux.enable;
    };
  };
}
