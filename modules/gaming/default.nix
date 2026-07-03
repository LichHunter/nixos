{
  config,
  lib,
  pkgs,
  username,
  ...
}:

with lib;

let
  cfg = config.dov.gaming;
in
{
  options.dov.gaming = {
    enable = mkEnableOption "gaming config";
  };

  config = mkIf cfg.enable {
    programs.steam = {
      enable = true;
      protontricks.enable = true;
      extraCompatPackages = with pkgs; [ proton-ge-bin ];
    };

    home-manager.users.${username}.config = {
      programs.lutris = {
        enable = true;
        extraPackages = with pkgs; [
          umu-launcher
          winetricks
        ];
        protonPackages = [ pkgs.proton-ge-bin ];
      };

      home.packages = with pkgs; [
        umu-launcher
      ];

      home.file.".local/share/Steam/compatibilitytools.d/GE-Proton" = {
        source = "${pkgs.proton-ge-bin.steamcompattool}";
      };
    };

    users.users."${username}" = {
      packages = with pkgs; [
        prismlauncher
      ];
    };
  };
}
