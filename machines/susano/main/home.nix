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
          nixos-build = "nixos-rebuild build --flake ~/nixos/#${username}";
          nixos-test = "sudo nixos-rebuild test --flake ~/nixos/#${username}";
          nixos-switch = "sudo nixos-rebuild switch --flake ~/nixos/#${username}";
          nixos-boot = "sudo nixos-rebuild boot --flake ~/nixos/#${username}";
        };
      };

      addition = {
        starship.enable = true;
        oxidise.enable = true;
        tmux.enable = true;
        fzf.enable = true;
      };
    };
  };

  programs.home-manager.enable = true;
}
