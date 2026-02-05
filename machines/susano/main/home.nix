{ config, lib, pkgs, inputs, extraHomeModules, ... }:

let
  username = "susano";
in {
  imports = [
  ];


  home = {
    stateVersion = "25.05";
    username = username;
    homeDirectory = "/home/${username}";

    packages = with pkgs; [
      eza
      git
    ];
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
}
