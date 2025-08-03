{ config, lib, pkgs, ... }:

{
  programs.direnv = {
    enable = true;

    enableNushellIntegration = config.dov.shell.nu.enable;
    enableZshIntegration = config.dov.shell.zsh.enable;
  };
}
