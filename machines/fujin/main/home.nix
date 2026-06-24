{ inputs, config, lib, pkgs, username, ... }:

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

      nu = {
        enable = true;
        shellAliases = {
          ll = "eza -al";
          cp = "rsync -ah --progress";
          nixos-build = "nixos-rebuild build --flake ~/nixos/#${username}";
          nixos-test = "sudo nixos-rebuild test --flake ~/nixos/#${username}";
          nixos-switch = "sudo nixos-rebuild switch --flake ~/nixos/#${username}";
          nixos-boot = "sudo nixos-rebuild boot --flake ~/nixos/#${username}";
          fuck = "thefuck $\"(history | last 1 | get command | get 0)\"";
        };
      };

      addition = {
        starship.enable = true;
        oxidise.enable = true;
        tmux.enable = true;
        fzf.enable = true;
      };
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

    development = {
      vscode.enable = true;
      jetbrains.toolbox.enable = true;
    };

    notification.mako.enable = true;

    dynamic-theme.enable = true;
  };

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;
      settings = {
        user = {
          name = "Alexander";
          email = "alexander0derevianko@gmail.com";
        };

        safe = {
          directory = ["/home/${username}/nixos-dotfiles" "/home/${username}/.cache/nix"];
        };
      };
      hooks = {
        commit-msg = pkgs.writeScript "commit-msg" ''
          #!${pkgs.bash}/bin/bash
          # Remove Co-Authored-by lines from commit messages (Claude likes to add these)
          ${pkgs.gnused}/bin/sed -i '/^Co-[Aa]uthored-[Bb]y:/d' "$1"
        '';
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
    #thunderbird-latest
    element-desktop
    #teams-for-linux
    #webcord
    discord

    # development
    jetbrains.idea
    jetbrains.webstorm
    #jetbrains.pycharm-community-src
    direnv
    devenv
    semgrep
    devpod
    tmux
    #bottles
    terraform
    kubectl
    kubectx
    ansible
    btop
    htop
    nvitop
    tree
    bruno

    #torrent
    qbittorrent

    #kdePackages.kate
    kdePackages.ark
    keepassxc
    #virt-manager
    #vial #keyboard configurator
    #qmk
    google-chrome
    unzip

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

    # gaming
    prismlauncher
  ] ++ [ inputs.thefuck.packages.${pkgs.system}.default ];

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
