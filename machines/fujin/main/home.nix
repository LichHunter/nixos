{ config, lib, pkgs, username, ... }:

{
  home = {
    stateVersion = "25.11";
    username = username;
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
          nixos-build = "nixos-rebuild build --flake ~/nixos/#${username}";
          nixos-test = "sudo nixos-rebuild test --flake ~/nixos/#${username}";
          nixos-switch = "sudo nixos-rebuild switch --flake ~/nixos/#${username}";
          nixos-boot = "sudo nixos-rebuild boot --flake ~/nixos/#${username}";
        };
      };

      addition.starship.enable = true;
      addition.oxidise.enable = true;
    };

    browser.zen.enable = true;

    #window-manager.hypr.enable = true;

    bar.waybar.enable = true;

    launcher.wofi.enable = true;

    kanshi.enable = true;

    terminal = {
      alacritty.enable = true;
      ghostty = {
        enable = true;
        shell = "${pkgs.nushell}/bin/nu";
      };
    };
  };

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;
      userName = "Alexander";
      userEmail = "alexander0derevianko@gmail.com";

      extraConfig = {
        safe = {
          directory = ["/home/${username}/nixos-dotfiles" "/home/${username}/.cache/nix"];
        };
      };
    };
  };

  home.packages = with pkgs; [
    eza

    # if you enable gtk theames
    # this is needed to fix "error: GDBus.Error:org.freedesktop.DBus.Error.ServiceUnknown: The name ca.desrt.dconf was not provided by any .service files"
    dconf

    # Video player
    vlc

    # social
    telegram-desktop
    thunderbird-latest
    element-desktop
    #teams-for-linux
    #webcord
    discord

    # development
    jetbrains.idea-ultimate
    jetbrains.webstorm
    #jetbrains.pycharm-community-src
    direnv
    semgrep
    devpod
    tmux
    bottles

    #torrent
    qbittorrent

    #kdePackages.kate
    kdePackages.ark
    keepassxc
    #virt-manager
    #vial #keyboard configurator
    #qmk

    #libreoffice
    grim
    slurp
    wl-clipboard
    #cloudflared
    kdePackages.okular #pdf tool
    #nextcloud-client

    #music
    #mpd
    #mpv
    #mpc-cli
  ];

  stylix = {
    enable = true;
    autoEnable = true;
    targets = {
      kde.enable = false;
    };
  };

  # blutooth applet
  services.blueman-applet.enable = true;
}
