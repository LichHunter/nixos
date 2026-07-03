{ inputs, config, lib, pkgs, username, extraHomeModules, ... }:

{
  imports = [
    ../../minimal.nix
    ../hardware-configuration.nix
    ../disko-config.nix

    #./sops.nix
  ];

  nixpkgs.overlays = [
    (import ./overlays/zulu22.nix)
  ];

  security.pki.certificateFiles = [
    ./certs/homelab-com.pem
    ./certs/homelab-lan-chain.crt
  ];

  users.users.${username} = {
    description = "NixOS Omen Laptop";
    hashedPassword =
      "$6$5xuxfP8HapkkyDa5$qr2wkpibMaNSIiJIPojWC4CO1X31HNJZEfmYfReYrwOSoflf0rMrQk.EZj5uzh/K/NalQMnCiDcmvFBuf9a5p0";
    packages = with pkgs; [
      # thunar plugin to manager archives
      thunar-archive-plugin

      # Stow, to manage my doom emacs configs
      stow

      # split keyboard configuration managers
      vial
      via
      qmk
    ];

    shell = lib.mkForce pkgs.nushell;
  };

  # virtualisation.virtualbox.host.enable = true;
  # virtualisation.virtualbox.guest.enable = true;
  # virtualisation.virtualbox.guest.dragAndDrop = true;
  # users.extraGroups.vboxusers.members = [ "${username}" ];

  programs = {
    fuse.userAllowOther = true;

    nix-ld.dev.enable = true;

    nm-applet.enable = true;

    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };

  boot.loader.grub = {
    minegrub-theme = {
      enable = true;
      splash = "100% Flakes!";
      background = "background_options/1.8  - [Classic Minecraft].png";
      boot-options-count = 10;
    };
  };

  networking = {
    nameservers = [
      "192.168.1.2" # PyHole
      "192.168.1.1" # Router
      "1.1.1.1"
    ];
    dhcpcd.extraConfig = ''
      nohook resolv.conf
    '';
    networkmanager.enable = true;
  };

  ###
  # Thunar configurations
  ###
  programs.thunar.enable = true;
  programs.xfconf.enable = true; # needed to save preferences
  services.gvfs.enable = true; # Mount, trash, and other functionalities
  services.tumbler.enable = true; # Thumbnail support for images
  ###
  ###

  services.tailscale.enable = true;

  services.personal-backlog = {
    enable = true;
    port = 48080;
    user = "${username}";
    group = "users";
    dataDir = "/home/fujin/.local/share/backlog";
  };

  # Keyboard configuraions
  services.udev = {

    packages = with pkgs; [
      qmk
      qmk-udev-rules # the only relevant
      qmk_hid
      via
      vial
    ]; # packages

  }; # udev

  dov = {
    development.emacs.enable = true;

    virtualisation.docker.enable = true;
    virtualisation.incus.enable = true;

    window-manager.hypr.enable = true;

    display-manager.ly.enable = true;

    gaming.enable = true;
  };

  ###
  # Home Manger configuration
  ###
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs username; };
    # Stylix is handled entirely at the Home Manager level (see
    # hm-modules/theme). Load the stylix HM module here so the `stylix`
    # option exists for fujin's home configuration.
    sharedModules = [ inputs.stylix.homeModules.stylix ];

    users."${username}" = { imports = [ ./home.nix ] ++ extraHomeModules; };
  };

  fonts.packages = with pkgs;
    [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      liberation_ttf
      fira-code
      fira
      fira-code-symbols
      mplus-outline-fonts.githubRelease
      dina-font
      proggyfonts
      emacs-all-the-icons-fonts
      emacs.pkgs.all-the-icons
      font-awesome_5
      source-code-pro
    ] ++ builtins.filter lib.attrsets.isDerivation
    (builtins.attrValues pkgs.nerd-fonts);

  # DO NOT CHANGE AT ANY POINT!
  system.stateVersion = "25.11";
}
