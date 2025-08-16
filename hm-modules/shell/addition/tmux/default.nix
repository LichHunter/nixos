{ config, lib, pkgs, username, ... }:

with lib;

let cfg = config.dov.shell.addition.tmux;
in {
  options.dov.shell.addition.tmux.enable = mkEnableOption "tmux configuration";

  config = mkIf cfg.enable {
    programs.tmux = {
      enable = cfg.enable;
      shell = "${pkgs.nushell}/bin/nu"; # TODO there should be some way to get current shell of user to insert here
      terminal = "tmux-256color";
      historyLimit = 100000;
      plugins = with pkgs;
        [
          tmuxPlugins.better-mouse-mode
        ];
      extraConfig = ''
      '';
    };
  };
}
