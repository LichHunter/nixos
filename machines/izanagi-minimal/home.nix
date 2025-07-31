{ config, lib, pkgs, username, ... }:

let
in {
  imports = [
  ];


  home = {
    inherit username;
    stateVersion = "25.05";
    homeDirectory = "/home/${username}";
  };

  dov = {
    shell = {
      zsh = {
        enable = true;
        shellAliases = {
          ll = "eza -al";
          sc = "source $HOME/.zshrc";
          psax = "ps ax | grep";
          cp = "rsync -ah --progress";
        };
      };
    };
  };

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    eza
  ];
}
