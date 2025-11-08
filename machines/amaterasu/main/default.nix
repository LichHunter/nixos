{ config, pkgs, extraHomeModules, inputs, lib, username, ... }:

let
  flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
in {
  imports =
    [
      ../../minimal.nix

      ../hardware-configuration.nix
      ../disko-config.nix
      ./sops.nix
    ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
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
      trusted-users = [ "root" username ];
    };
    # Opinionated: disable channels
    channel.enable = false;

    # Opinionated: make flake registry and nix path match flake inputs
    registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
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
    description = "NixOS Proxmox Builder";
    hashedPassword = "$6$00vM.zXgahhw6KQO$BpCilKSdUNDlIaOlGrWJAdzh7KCIYoW3uoC1VV9I0eaJyui7J0Yv6BCajGwrn0JwrgWmvOfEMPeyGs4/wWD9q.";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBcGhVpjmWEw1GEw0y/ysJPa2v3+u/Rt/iES/Se2huH2 alexander0derevianko@gmail.com"
      # Nix config builder
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID4PqgSP0tIDsHyVNKAYGsYfDsJA2TqI3V0006uihXmI izanagi@izanagi"
    ];
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    ripgrep
    vault
  ];

  services = {
    openssh = {
      enable = true;
      settings = {
        # Opinionated: forbid root login through SSH.
        PermitRootLogin = "no";
        # Opinionated: use keys only.
        # Remove if you want to SSH using passwords
        PasswordAuthentication = false;
      };
    };

    tailscale.enable = true;
  };

  programs = {
    zsh.enable = true;
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
      ] ++ extraHomeModules;
    };
  };

  ###
  # My Services
  ###
  dov = {
    gitlab.enable = true;
    jenkins.enable = true; # will migrate to gitlab runner
  };

  # DO NOT CHANGE AT ANY POINT!
  system.stateVersion = "25.05";
}
