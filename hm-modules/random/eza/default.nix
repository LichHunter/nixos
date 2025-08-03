{ config, lib, pkgs, ... }:

{
  programs.eza = {
    enable = true;
    git = true;

    enableZshIntegration = config.dov.shell.zsh.enable;
    enableNushellIntegration = config.dov.shell.nu.enable;
  };
}
