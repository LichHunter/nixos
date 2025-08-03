{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.shell.addition.oxidise;
in {
  options.dov.shell.addition.oxidise = {
    enable = mkEnableOption "oxidise config";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      fd
      bat
      eza
      dust
      dua # graphical tui du
    ];

    programs.zoxide = {
      enable = true;
      enableZshIntegration = config.dov.shell.zsh.enable;
    };

    dov.shell.zsh = mkIf config.dov.shell.zsh.enable {
      shellAliases = {
        find = mkForce "fd";
        cat = mkForce "bat";
        ls = mkForce "eza";
        cd = mkForce "z";
        du = mkForce "dust";
      };
    };
  };

}
