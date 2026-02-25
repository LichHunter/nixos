{
  config,
  pkgs,
  extraHomeModules,
  inputs,
  lib,
  username,
  ...
}:

let
  flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
in
{
  imports = [
    ../../minimal.nix

    ../hardware-configuration.nix
    ../disko-config.nix
    ./sops.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # If you want to use overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  nix = {
    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Opinionated: disable global registry
      flake-registry = "";
      # Workaround for https://github.com/NixOS/nix/issues/9574
      nix-path = config.nix.nixPath;

      # Allow user to reubild nixos without sudo
      trusted-users = [
        "root"
        username
      ];
    };
    # Opinionated: disable channels
    channel.enable = false;

    # Opinionated: make flake registry and nix path match flake inputs
    registry = lib.mkForce (lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs);
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
  };

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.useOSProber = true;

  networking.hostName = username;
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Warsaw";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  security.rtkit.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    description = "NixOS Proxmox Homelab";
    hashedPassword = "$6$7LSgOtcEozV0gkN9$pCltKL683UqJ3M7C4ZIgZsytAGtQS375g64ckuJQPFtUjxiGCxehJtkP91Pba.rIZNe3eZqnJfIQNwnJWmyVJ0";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    packages = with pkgs; [
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBcGhVpjmWEw1GEw0y/ysJPa2v3+u/Rt/iES/Se2huH2 alexander0derevianko@gmail.com"
    ];
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    ripgrep
  ];

  services.openssh = {
    enable = true;
    settings = {
      # Opinionated: forbid root login through SSH.
      PermitRootLogin = "no";
      # Opinionated: use keys only.
      # Remove if you want to SSH using passwords
      PasswordAuthentication = false;
    };
  };

  programs = {
    zsh.enable = true;

    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };

  ###
  # Home Manger configuration
  ###
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs username; };

    users."${username}" = {
      imports = [
        ./home.nix
      ]
      ++ extraHomeModules;
    };
  };

  ###
  # My Services
  ###
  dov = {
    development.emacs.enable = true;

    # Reverse Proxy
    reverse-proxy = {
      nginx.enable = false; # TODO does not work for some reason
      traefik.enable = true;
      caddy.enable = false; # TODO has issues retrieving certificate from duckdns
    };

    virtualisation = {
      podman.enable = false;
      docker.enable = true;
    };

    social.matrix.enable = false; # TODO does not work :)

    file-server.copyparty.enable = false;

    samba.enable = true;

    searxng.enable = true;

    auth = {
      authelia.enable = false; # TODO needs configuration with nginx or traefik
      # ldap.enable = false; # TODO too hard to setup, will need to take a look later
    };
  };

  # DO NOT CHANGE AT ANY POINT!
  system.stateVersion = "25.05";
}
