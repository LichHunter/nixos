{ inputs, config, lib, pkgs, username, extraHomeModules, ... }:

{
  imports = [
    ../../minimal.nix

    ../hardware-configuration.nix
    ../disko-config.nix
  ];

  users.users.${username} = {
    description = "NixOS Omen Laptop";
    hashedPassword =
      "$6$5xuxfP8HapkkyDa5$qr2wkpibMaNSIiJIPojWC4CO1X31HNJZEfmYfReYrwOSoflf0rMrQk.EZj5uzh/K/NalQMnCiDcmvFBuf9a5p0";
    packages = with pkgs; [ ];
  };

  networking.networkmanager.enable = true;

  ###
  # Home Manger configuration
  ###
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs username; };

    users."${username}" = { imports = [ ./home.nix ] ++ extraHomeModules; };
  };

  # DO NOT CHANGE AT ANY POINT!
  system.stateVersion = "25.11";
}
