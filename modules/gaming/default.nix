{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.gaming;
in {
  options.dov.gaming = {
    enable = mkEnableOption "gaming config";
  };

  config = mkIf cfg.enable {
    programs.steam = {
      enable = true;
      protontricks.enable = true;
      extraCompatPackages = with pkgs; [ proton-ge-bin ];
    };
  };
}
